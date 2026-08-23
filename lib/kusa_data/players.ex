defmodule KusaData.Players do
  @moduledoc """
  Player profile and set-history analytics.

  `history/2` fetches the FULL set history (no six-page truncation) with
  optional filters, returning a continuation when the upstream page budget
  prevents completion so callers can resume. `compare/3`, `head_to_head/3`,
  and `trend/2` are backed by that normalized history; placement data comes
  from the cached per-event bracket analytics.
  """

  @identity_ttl 15 * 60
  @history_ttl 15 * 60
  @per_page 40
  @max_pages 50
  @compare_events_limit 12

  alias KusaData.Cache
  alias KusaData.Events
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @spec profile(integer()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def profile(player_id) do
    Cache.fetch("player:#{player_id}:identity", @identity_ttl, fn ->
      {document, variables} = Queries.player_identity(player_id)

      with {:ok, data} <- Client.query(document, variables),
           %{"player" => %{} = player} <- data do
        user = player["user"] || %{}

        {:ok,
         %{
           "player_id" => player["id"],
           "gamer_tag" => player["gamerTag"],
           "user_id" => user["id"],
           "prefix" => player["prefix"],
           "user_name" => user["name"],
           "bio" => user["bio"],
           "location" => location_string(user["location"]),
           "avatar_url" => avatar_url(user["images"])
         }}
      else
        %{"player" => nil} -> {:error, :not_found}
        _ -> {:error, :unexpected_response}
      end
    end)
  end

  defp location_string(nil), do: nil

  defp location_string(location) do
    [location["city"], location["state"], location["country"]]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp avatar_url(images) when is_list(images) do
    case Enum.find(images, & &1["url"]) do
      %{"url" => url} -> url
      _ -> nil
    end
  end

  defp avatar_url(_), do: nil

  @doc """
  Full, filterable set history for a player.

  Options (all optional): `event` (event id), `opponent` (opponent player id),
  `from`/`to` (unix bounds on `completedAt`), `game` (event videogame slug),
  and `from_page` (resume page for a continuation).

  Returns `%{"sets" => [...], "total" => n, "fetched" => n, "continuation" => page | nil}`
  where `continuation` is non-nil when the upstream page budget ran out before
  `totalPages` — the caller can resume with `from_page`.
  """
  @spec history(integer(), map()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def history(player_id, opts \\ %{}) do
    opts = Map.take(opts, [:event, :opponent, :from, :to, :game, :from_page])

    Cache.fetch(history_key(player_id, opts), @history_ttl, fn ->
      compute_history(player_id, opts)
    end)
  end

  defp compute_history(player_id, opts) do
    with {:ok, identity} <- fetch_identity(player_id),
         {:ok, sets, next_page} <- fetch_all_sets(player_id, opts[:from_page] || 1, []) do
      filtered = filter_sets(sets, opts)

      {:ok,
       %{
         "player_id" => player_id,
         "gamer_tag" => identity["gamer_tag"],
         "sets" => filtered,
         "total" => length(filtered),
         "fetched" => length(sets),
         "continuation" => next_page
       }}
    end
  end

  defp fetch_all_sets(player_id, page, acc) do
    with {:ok, data} <-
           Client.query_paged(
             fn per_page ->
               Queries.player_sets(player_id, page, per_page)
             end,
             @per_page
           ) do
      sets_info = data["player"]["sets"]
      nodes = sets_info["nodes"] || []
      total_pages = sets_info["pageInfo"]["totalPages"] || 1
      acc = acc ++ nodes

      cond do
        page >= total_pages ->
          {:ok, acc, nil}

        page >= @max_pages ->
          {:ok, acc, page + 1}

        true ->
          fetch_all_sets(player_id, page + 1, acc)
      end
    end
  end

  defp filter_sets(sets, opts) do
    sets
    |> maybe_filter_event(opts[:event])
    |> maybe_filter_opponent(opts[:opponent])
    |> maybe_filter_dates(opts[:from], opts[:to])
    |> maybe_filter_game(opts[:game])
  end

  defp maybe_filter_event(sets, nil), do: sets

  defp maybe_filter_event(sets, event_id) do
    Enum.filter(sets, fn set ->
      to_string(set["event"]["id"]) == to_string(event_id)
    end)
  end

  defp maybe_filter_opponent(sets, nil), do: sets

  defp maybe_filter_opponent(sets, opponent_id) do
    Enum.filter(sets, fn set ->
      Enum.any?(set["slots"] || [], fn slot ->
        slot["entrant"]["participants"]
        |> Enum.any?(fn participant ->
          match?(%{"player" => %{"id" => id}} when id == opponent_id, participant["user"])
        end)
      end)
    end)
  end

  defp maybe_filter_dates(sets, nil, nil), do: sets

  defp maybe_filter_dates(sets, from, to) do
    Enum.filter(sets, fn set ->
      completed = set["completedAt"]
      after? = is_nil(from) or (is_integer(completed) and completed >= from)
      before? = is_nil(to) or (is_integer(completed) and completed <= to)
      after? and before?
    end)
  end

  defp maybe_filter_game(sets, nil), do: sets

  defp maybe_filter_game(sets, game) do
    Enum.filter(sets, fn set ->
      set["event"]["videogame"]["slug"] == game
    end)
  end

  defp history_key(player_id, opts) do
    canonical =
      %{
        "event" => opts[:event],
        "opponent" => opts[:opponent],
        "from" => opts[:from],
        "to" => opts[:to],
        "game" => opts[:game],
        "from_page" => opts[:from_page]
      }
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    "player:#{player_id}:history:#{canonical}"
  end

  @doc """
  Side-by-side comparison of two players: overall record, event finishes,
  opponent records, and monthly time buckets.

  `opts` accepts `game` to scope both players' histories.
  """
  @spec compare(integer(), integer(), map()) ::
          {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def compare(player_a, player_b, opts \\ %{}) do
    key = "compare:#{pair_key(player_a, player_b)}:#{opts[:game]}"

    Cache.fetch(key, @history_ttl, fn ->
      with {:ok, a} <- summarize(player_a, opts[:game]),
           {:ok, b} <- summarize(player_b, opts[:game]),
           {:ok, ha, _} <- history(player_a, %{game: opts[:game]}),
           {:ok, hb, _} <- history(player_b, %{game: opts[:game]}) do
        {:ok,
         %{
           "players" => [a, b],
           "head_to_head" =>
             h2h_from_sets(
               ha["sets"],
               hb["sets"],
               player_a,
               player_b,
               a["gamer_tag"],
               b["gamer_tag"]
             ),
           "comparison" => %{"events_overlap" => overlap_events(a, b)}
         }}
      end
    end)
  end

  @doc """
  Summary card for the player-settings page: overall record, event finishes,
  and opponent records (same shape as one side of `compare/3`).
  """
  @spec card(integer(), String.t() | nil) ::
          {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def card(player_id, game \\ nil) do
    Cache.fetch("player:#{player_id}:card:#{game}", @history_ttl, fn ->
      with {:ok, summary} <- summarize(player_id, game) do
        {:ok, summary}
      end
    end)
  end

  defp summarize(player_id, game) do
    with {:ok, identity} <- fetch_identity(player_id) do
      with {:ok, history, _} <- history(player_id, %{game: game}) do
        sets = history["sets"]
        completed = Enum.filter(sets, &completed?/1)

        {wins, losses} =
          Enum.reduce(completed, {0, 0}, fn set, {w, l} ->
            if won_by?(set, player_id), do: {w + 1, l}, else: {w, l + 1}
          end)

        total = wins + losses
        win_rate = if total == 0, do: 0.0, else: round(wins * 1000 / total) / 10

        {:ok,
         %{
           "player_id" => player_id,
           "gamer_tag" => identity["gamer_tag"],
           "wins" => wins,
           "losses" => losses,
           "win_rate" => win_rate,
           "sets_seen" => length(sets),
           "events_entered" => events_entered(sets),
           "finishes" => finishes(player_id, sets),
           "opponents" => opponent_records(player_id, completed),
           "time_buckets" => time_buckets(player_id, completed)
         }}
      end
    end
  end

  defp won_by?(set, player_id) do
    Enum.any?(set["slots"] || [], fn slot ->
      slot["entrant"]["id"] == set["winnerId"] and
        Enum.any?(slot["entrant"]["participants"] || [], fn p ->
          match?(%{"player" => %{"id" => ^player_id}}, p["user"])
        end)
    end)
  end

  defp completed?(set), do: set["completedAt"] != nil and set["winnerId"] != nil

  defp events_entered(sets) do
    sets |> Enum.map(& &1["event"]["id"]) |> Enum.uniq() |> length()
  end

  # Best placements from the cached per-event bracket analytics.
  defp finishes(player_id, sets) do
    sets
    |> Enum.map(& &1["event"]["id"])
    |> Enum.uniq()
    |> Enum.take(@compare_events_limit)
    |> Task.async_stream(
      fn event_id -> {event_id, placement_for(player_id, event_id)} end,
      max_concurrency: 6,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.flat_map(fn
      {:ok, {event_id, {:ok, placement}}} -> [%{"event_id" => event_id, "placement" => placement}]
      _ -> []
    end)
    |> Enum.sort_by(& &1["placement"])
  end

  defp placement_for(player_id, event_id) do
    case Events.analytics(event_id) do
      {:ok, data, _} ->
        case Enum.find(data["analysis"]["entrants"], &(&1["player_id"] == player_id)) do
          %{"placement" => placement} -> {:ok, placement}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp opponent_records(player_id, completed) do
    completed
    |> Enum.group_by(fn set -> opponent_identity(set, player_id) end)
    |> Enum.map(fn {identity, sets} ->
      wins = Enum.count(sets, &won_by?(&1, player_id))

      %{
        "opponent_player_id" => identity[:player_id],
        "name" => identity[:name],
        "unresolved" => identity[:player_id] == nil,
        "wins" => wins,
        "losses" => length(sets) - wins,
        "total" => length(sets)
      }
    end)
    |> Enum.sort_by(& &1["total"], :desc)
    |> Enum.take(10)
  end

  defp opponent_identity(set, player_id) do
    opponent = opponent_slot(set, player_id)

    player_id =
      Enum.find_value(opponent["entrant"]["participants"] || [], fn p ->
        case p["user"] do
          %{"player" => %{"id" => id}} -> id
          _ -> nil
        end
      end)

    %{player_id: player_id, name: opponent["entrant"]["name"]}
  end

  defp opponent_slot(set, player_id) do
    Enum.find(set["slots"] || [], fn slot ->
      not Enum.any?(slot["entrant"]["participants"] || [], fn p ->
        match?(%{"player" => %{"id" => ^player_id}}, p["user"])
      end)
    end) || %{"entrant" => %{"name" => "—"}}
  end

  defp time_buckets(player_id, completed) do
    completed
    |> Enum.group_by(fn set -> month_key(set["completedAt"]) end)
    |> Enum.map(fn {month, sets} ->
      wins = Enum.count(sets, &won_by?(&1, player_id))

      %{
        "month" => month,
        "sets" => length(sets),
        "wins" => wins,
        "losses" => length(sets) - wins,
        "win_rate" => round(wins * 1000 / length(sets)) / 10
      }
    end)
    |> Enum.sort_by(& &1["month"])
  end

  defp month_key(nil), do: "unknown"

  defp month_key(unix) when is_integer(unix) do
    unix |> DateTime.from_unix!() |> Calendar.strftime("%Y-%m")
  end

  defp month_key(_), do: "unknown"

  defp overlap_events(a, b) do
    a_events = a["finishes"] |> Enum.map(& &1["event_id"]) |> MapSet.new()
    b_events = b["finishes"] |> Enum.map(& &1["event_id"]) |> MapSet.new()
    MapSet.intersection(a_events, b_events) |> MapSet.to_list() |> length()
  end

  @doc """
  Head-to-head record between two players, joined on player id.

  Sets where either side lacks a player id are reported separately under
  `unresolved_sets` (matched by display name only for reporting) and never
  counted toward the record, so identity gaps can't skew the result.
  """
  @spec head_to_head(integer(), integer(), map()) ::
          {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def head_to_head(player_a, player_b, opts \\ %{}) do
    key = "h2h:#{pair_key(player_a, player_b)}:#{opts[:game]}"

    Cache.fetch(key, @history_ttl, fn ->
      with {:ok, history_a, _} <- history(player_a, %{game: opts[:game]}),
           {:ok, history_b, _} <- history(player_b, %{game: opts[:game]}),
           {:ok, identity_a, _} <- profile(player_a),
           {:ok, identity_b, _} <- profile(player_b) do
        {:ok,
         h2h_from_sets(
           history_a["sets"],
           history_b["sets"],
           player_a,
           player_b,
           identity_a["gamer_tag"],
           identity_b["gamer_tag"]
         )}
      end
    end)
  end

  # Counts sets by player id; name-only sets involving the two players are
  # reported as unresolved without affecting the record.
  defp h2h_from_sets(a_sets, b_sets, player_a, player_b, name_a, name_b) do
    a_vs_b = Enum.filter(a_sets, &opponent_is?(&1, player_b))
    b_vs_a = Enum.filter(b_sets, &opponent_is?(&1, player_a))
    all = Enum.uniq_by(a_vs_b ++ b_vs_a, & &1["id"])

    a_wins = Enum.count(all, &won_by?(&1, player_a))
    b_wins = Enum.count(all, &won_by?(&1, player_b))

    unresolved =
      Enum.count(a_sets, &name_only_opponent?(&1, player_a, name_b)) +
        Enum.count(b_sets, &name_only_opponent?(&1, player_b, name_a))

    %{
      "sets" => length(all),
      "player_a_wins" => a_wins,
      "player_b_wins" => b_wins,
      "unresolved_sets" => unresolved
    }
  end

  defp pair_key(a, b) when a <= b, do: "#{a}:#{b}"
  defp pair_key(a, b), do: "#{b}:#{a}"

  # A set whose opponent slot has no player id but whose display name matches
  # the other player's tag — reported, never counted.
  defp name_only_opponent?(set, player_id, other_name) do
    case opponent_slot(set, player_id) do
      %{"entrant" => %{"participants" => participants, "name" => name}} ->
        no_player? =
          not Enum.any?(participants || [], fn p ->
            match?(%{"player" => %{"id" => _}}, p["user"])
          end)

        no_player? and name == other_name

      _ ->
        false
    end
  end

  defp opponent_is?(set, player_id) do
    Enum.any?(set["slots"] || [], fn slot ->
      Enum.any?(slot["entrant"]["participants"] || [], fn p ->
        match?(%{"player" => %{"id" => ^player_id}}, p["user"])
      end)
    end)
  end

  @doc """
  Chronological monthly trend: win rate plus best placement per month.
  """
  @spec trend(integer(), map()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def trend(player_id, opts \\ %{}) do
    key = "trend:#{player_id}:#{opts[:game]}"

    Cache.fetch(key, @history_ttl, fn ->
      with {:ok, summary} <- summarize(player_id, opts[:game]) do
        buckets =
          Enum.map(summary["time_buckets"], fn bucket ->
            best_placement =
              summary["finishes"]
              |> Enum.filter(fn finish -> finish_month(finish["event_id"]) == bucket["month"] end)
              |> Enum.map(& &1["placement"])
              |> Enum.min(fn -> nil end)

            Map.put(bucket, "best_placement", best_placement)
          end)

        {:ok,
         %{
           "player_id" => player_id,
           "gamer_tag" => summary["gamer_tag"],
           "buckets" => buckets
         }}
      end
    end)
  end

  defp finish_month(event_id) do
    case Events.analytics(event_id) do
      {:ok, data, _} ->
        month_key(data["event"]["startAt"] || data["analysis"]["context"]["start_at"])

      _ ->
        "unknown"
    end
  end

  defp fetch_identity(player_id) do
    case profile(player_id) do
      {:ok, identity, _status} -> {:ok, identity}
      error -> error
    end
  end
end
