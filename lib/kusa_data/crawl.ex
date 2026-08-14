defmodule KusaData.Crawl do
  @moduledoc """
  The rankings crawler. One bounded slice per game: window-walks backward
  through 7-day slices up to 90 days, prefers the singles bracket, isolates
  per-tournament failures (a bad tournament never stalls the slice), applies
  Elo chronologically (path-independent), and persists players/ratings/
  tournaments/events/sets plus the window cursor and seen-set to Postgres.

  Per-game isolation is guaranteed: a game only ever queries its own
  videogameId and its own crawl_state row, so one game's data is never
  cross-scored into another's leaderboard.
  """

  alias KusaData.{Game, Event, Set, Player, Repo, Tournament, CrawlState, Elo}

  @window_days 90
  @window_seconds 7 * 86_400
  @window_per_page 90
  @sets_per_page 50
  @slice_tournaments 10
  @sweep_attempts 20

  alias KusaData.Crawl.{API, Result}

  @type result :: Result.t()

  @doc "Runs one crawl slice for `game_id`. Opts: `:now` (unix seconds) for tests."
  @spec run(pos_integer, keyword) :: {:ok, result} | {:error, term}
  def run(game_id, opts \\ []) do
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, game} <- fetch_game(game_id),
         state = load_state(game.id),
         {:ok, pending, window_end} <- find_pending(game, state, now) do
      data = ingest_pending(game, pending)
      persist(game, data, window_end, state)
    end
  end

  defp fetch_game(game_id) do
    case Repo.get(Game, game_id) do
      nil -> {:error, :no_such_game}
      game -> {:ok, game}
    end
  end

  defp load_state(game_id) do
    state = Repo.get_by(CrawlState, game_id: game_id)
    %{window_end: state && state.window_end, seen: (state && state.seen_ids) || []}
  end

  # ---- pool selection (window-walk) ---------------------------------------

  # Walks backward from the stored window end (or now) in 7-day slices until it
  # finds tournaments not yet seen, or exhausts the 90-day cutoff.
  defp find_pending(game, state, now) do
    after_date = now - @window_days * 86_400
    window_end = max(state.window_end || now, after_date)
    walk(game.videogame_id, window_end, after_date, now, state.seen, @sweep_attempts)
  end

  defp walk(_vid, _window_end, _after_date, _now, _seen, 0), do: {:ok, [], 0}

  defp walk(vid, window_end, after_date, now, seen, attempts) do
    window_start = max(window_end - @window_seconds, after_date)

    case API.get_pool(vid, window_start, @window_per_page, 1, window_end) do
      {:ok, pool} ->
        unseen = Enum.reject(pool, fn t -> t.id in seen end)

        cond do
          unseen != [] ->
            {:ok, unseen, window_end}

          window_start <= after_date ->
            {:ok, [], window_end}

          true ->
            walk(vid, window_start, after_date, now, seen, attempts - 1)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---- ingestion ----------------------------------------------------------

  # Ingests up to SLICE_TOURNAMENTS pending tournaments, applying chronologically.
  defp ingest_pending(game, pending) do
    pending = Enum.take(pending, @slice_tournaments)

    {tournaments, names, skipped, buffered} =
      Enum.reduce(pending, {[], %{}, 0, []}, fn t, {tournaments, names, skipped, buffered} ->
        case ingest_tournament(t, game) do
          {:ok, tournament} ->
            names = Map.merge(names, tournament.names)
            {[tournament | tournaments], names, skipped, buffered ++ tournament.sets}

          :skip ->
            {tournaments, names, skipped + 1, buffered}
        end
      end)

    {ratings, sets_applied} = apply_chronologically(buffered)

    %{
      pending: pending,
      tournaments: Enum.reverse(tournaments),
      names: names,
      skipped: skipped,
      sets_applied: sets_applied,
      ratings: ratings
    }
  end

  defp ingest_tournament(t, game) do
    case API.get_game_event(t.slug, game.videogame_id) do
      :error ->
        :skip

      {:ok, event_id} ->
        {sets, names} = fetch_all_sets(event_id)
        {:ok, %{tournament: t, event_id: event_id, sets: sets, names: names}}
    end
  end

  defp fetch_all_sets(event_id), do: fetch_sets_page(event_id, 1, [], %{})

  defp fetch_sets_page(event_id, page, acc, names) do
    case API.get_event_sets(event_id, page, @sets_per_page) do
      {:ok, sets, total_pages} ->
        names = collect_players_names(sets, names)

        if page < total_pages do
          fetch_sets_page(event_id, page + 1, acc ++ sets, names)
        else
          {acc ++ sets, names}
        end

      {:error, _reason} ->
        {acc, names}
    end
  end

  defp collect_players_names(sets, names) do
    slots =
      Enum.flat_map(sets, fn set -> set["slots"] || [] end)

    Enum.reduce(slots, names, fn slot, names -> put_name(names, slot) end)
  end

  defp put_name(names, slot) do
    case get_in(slot, ["entrant", "participants", Access.at(0)]) do
      %{"user" => %{"id" => user_id}} = p ->
        Map.put(names, user_id, %{
          gamer_tag: p["gamerTag"],
          prefix: p["prefix"],
          player_id: get_in(p, ["user", "player", "id"])
        })

      _ ->
        names
    end
  end

  defp apply_chronologically(sets) do
    sets
    |> Enum.filter(fn s -> not is_nil(s["completedAt"]) end)
    |> Enum.sort_by(fn s -> sort_timestamp(s["completedAt"]) end)
    |> Enum.reduce({%{}, 0}, fn set, {ratings, count} ->
      case Elo.apply_set(ratings, normalize_set(set)) do
        {:ok, new_ratings} -> {new_ratings, count + 1}
        :ignore -> {ratings, count}
      end
    end)
  end

  # start.gg returns completedAt as a unix epoch integer (or an ISO string in
  # some fixtures/paths); normalize both to a comparable integer for ordering.
  defp sort_timestamp(ts) when is_integer(ts), do: ts

  defp sort_timestamp(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      _ -> 0
    end
  end

  # The Elo engine works on atom-keyed maps; start.gg returns string-keyed
  # maps. Normalize just the fields Elo reads.
  defp normalize_set(set) do
    %{
      state: set["state"],
      completed_at: set["completedAt"],
      slots: Enum.map(set["slots"] || [], &normalize_slot/1)
    }
  end

  defp normalize_slot(slot) do
    participant = get_in(slot, ["entrant", "participants", Access.at(0)]) || %{}

    %{
      entrant: %{participants: [%{user: %{id: get_in(participant, ["user", "id"])}}]},
      standing: %{
        stats: %{score: %{value: get_in(slot, ["standing", "stats", "score", "value"])}}
      }
    }
  end

  # ---- persistence --------------------------------------------------------

  defp persist(game, data, window_end, state) do
    Repo.transaction(fn ->
      player_ids = persist_players(data.names)
      persist_ratings(game, data.ratings, player_ids)
      persist_tournaments(game, data.tournaments, player_ids)
      persist_state(game.id, Enum.map(data.tournaments, & &1.tournament), window_end, state)
    end)
    |> case do
      {:ok, _} ->
        {:ok,
         %Result{
           tournaments: length(data.pending),
           sets_applied: data.sets_applied,
           skipped_tournaments: data.skipped,
           players: map_size(data.ratings)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_players(names) do
    Enum.reduce(names, %{}, fn {user_id, info}, acc ->
      player =
        Repo.get_by(Player, user_id: user_id) ||
          Repo.insert!(
            Player.changeset(%Player{}, %{
              user_id: user_id,
              player_id: info.player_id,
              gamer_tag: info.gamer_tag,
              prefix: info.prefix
            })
          )

      Map.put(acc, user_id, player.id)
    end)
  end

  defp persist_ratings(game, ratings, player_ids) do
    Enum.each(ratings, fn {user_id, rating} ->
      case Map.fetch(player_ids, user_id) do
        {:ok, player_id} -> Repo.replace_rating(game.id, player_id, rating)
        :error -> :ok
      end
    end)
  end

  defp persist_tournaments(game, tournaments, player_ids) do
    Enum.each(tournaments, fn %{tournament: t, event_id: event_id, sets: sets} ->
      tournament =
        Repo.get_by(Tournament, startgg_id: t.id) ||
          Repo.insert!(Tournament.changeset(%Tournament{}, %{startgg_id: t.id, slug: t.slug}))

      event =
        Repo.get_by(Event, startgg_id: event_id) ||
          Repo.insert!(
            Event.changeset(%Event{}, %{
              startgg_id: event_id,
              name: "Singles",
              tournament_id: tournament.id,
              game_id: game.id
            })
          )

      persist_sets(sets, event.id, player_ids)
    end)
  end

  defp persist_sets(sets, event_id, player_ids) do
    Enum.each(sets, fn set ->
      case extract_result(set, player_ids) do
        nil ->
          :ok

        {startgg_id, state, completed_at, winner_db, loser_db, winner_score, loser_score} ->
          Repo.insert!(
            Set.changeset(%Set{}, %{
              startgg_id: startgg_id,
              state: state,
              completed_at: parse_completed_at(completed_at),
              winner_player_id: winner_db,
              loser_player_id: loser_db,
              winner_score: winner_score,
              loser_score: loser_score,
              event_id: event_id
            }),
            conflict_target: [:startgg_id],
            on_conflict: :nothing
          )
      end
    end)
  end

  # Derives the winner/loser for a set from its two scored slots.
  defp extract_result(set, player_ids) do
    with {:ok, user_a, score_a, user_b, score_b} <- two_scores(set),
         {winner_user, ws, loser_user, ls} <- order(user_a, score_a, user_b, score_b),
         {:ok, wid} <- Map.fetch(player_ids, winner_user),
         {:ok, lid} <- Map.fetch(player_ids, loser_user) do
      {set["id"], set["state"], set["completedAt"], wid, lid, ws, ls}
    else
      _ -> nil
    end
  end

  defp two_scores(set) do
    scored =
      Enum.flat_map(set["slots"] || [], fn slot ->
        score = get_in(slot, ["standing", "stats", "score", "value"])
        user_id = get_in(slot, ["entrant", "participants", Access.at(0), "user", "id"])

        if is_nil(score) or is_nil(user_id) do
          []
        else
          [{user_id, score}]
        end
      end)

    case scored do
      [{user_a, score_a}, {user_b, score_b}] -> {:ok, user_a, score_a, user_b, score_b}
      _ -> :error
    end
  end

  defp order(user_a, score_a, user_b, score_b) do
    if score_a >= score_b do
      {user_a, score_a, user_b, score_b}
    else
      {user_b, score_b, user_a, score_a}
    end
  end

  defp parse_completed_at(nil), do: nil

  defp parse_completed_at(ts) when is_integer(ts), do: DateTime.from_unix!(ts)

  defp parse_completed_at(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_completed_at(_other), do: nil

  defp persist_state(game_id, pending, window_end, state) do
    seen = Enum.uniq((state.seen || []) ++ Enum.map(pending, & &1.id))

    case Repo.get_by(CrawlState, game_id: game_id) do
      nil ->
        Repo.insert!(
          CrawlState.changeset(%CrawlState{}, %{
            game_id: game_id,
            window_end: window_end,
            seen_ids: seen
          })
        )

      crawl_state ->
        Repo.update!(CrawlState.changeset(crawl_state, %{window_end: window_end, seen_ids: seen}))
    end
  end
end

defmodule KusaData.Repo do
  use Ecto.Repo,
    otp_app: :kusa_data,
    adapter: Ecto.Adapters.Postgres

  def replace_rating(game_id, player_id, rating) do
    attrs = %{
      game_id: game_id,
      player_id: player_id,
      elo: rating.elo,
      sets: rating.sets,
      wins: rating.wins,
      losses: rating.losses
    }

    changeset = KusaData.Rating.changeset(%KusaData.Rating{}, attrs)

    case insert(changeset,
           on_conflict: {:replace, [:elo, :sets, :wins, :losses]},
           conflict_target: [:game_id, :player_id]
         ) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end
end
