defmodule KusaData.Stats do
  @moduledoc """
  On-demand player stats.

  Fetches the player's recent set history (capped at `@max_pages` pages so a
  top player's 1,500+ sets don't wreck the response budget), computes stats
  with `KusaData.Stats.Engine`, and caches the result per player and game.

  `for_player/2` accepts an optional game slug: when given, only sets whose
  event belongs to that game are analyzed, so a Melee page never mixes sets
  from another game. Cache keys include the game so scoped and unscoped
  results stay separate.
  """

  @sets_per_page 40
  @max_pages 6
  @cache_ttl 15 * 60

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries
  alias KusaData.Players
  alias KusaData.Stats.Engine

  @spec for_player(integer(), String.t() | nil) ::
          {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def for_player(player_id, game \\ nil) do
    Cache.fetch(stats_key(player_id, game), @cache_ttl, fn -> compute(player_id, game) end)
  end

  @doc "Drops the cached stats so the next fetch is fresh."
  @spec clear_cache(integer(), String.t() | nil) :: :ok
  def clear_cache(player_id, game \\ nil) do
    Cache.delete(stats_key(player_id, game))
    :ok
  end

  @doc """
  Raw (bounded) set history for a player, optionally scoped to one game.

  Cached separately from the computed stats so rankings and analytics can
  reuse the same fetch without recomputing aggregates.
  """
  @spec raw_sets(integer(), String.t() | nil) ::
          {:ok, [map()], :hit | :miss | :bypass} | {:error, term()}
  def raw_sets(player_id, game \\ nil) do
    Cache.fetch("player:#{player_id}:raw_sets:#{game || "all"}", @cache_ttl, fn ->
      with {:ok, sets} <- fetch_sets(player_id) do
        sets = if game, do: Enum.filter(sets, &game_matches?(&1, game)), else: sets
        {:ok, sets}
      end
    end)
  end

  defp stats_key(player_id, nil), do: "player:#{player_id}:stats"
  defp stats_key(player_id, game), do: "player:#{player_id}:stats:#{game}"

  defp compute(player_id, game) do
    with {:ok, identity} <- fetch_identity(player_id) do
      with {:ok, sets} <- fetch_sets(player_id) do
        sets = if game, do: Enum.filter(sets, &game_matches?(&1, game)), else: sets

        {:ok,
         Engine.build(identity, sets)
         |> Map.merge(profile_fields(identity))
         |> Map.put("recent_events", recent_events(identity, sets))}
      end
    end
  end

  # Profile display fields ride along with the computed stats so the player
  # page renders them from one payload. Missing values stay nil and the UI
  # hides those elements.
  defp profile_fields(identity) do
    %{
      "prefix" => identity["prefix"],
      "user_name" => identity["user_name"],
      "bio" => identity["bio"],
      "location" => identity["location"],
      "avatar_url" => identity["avatar_url"]
    }
  end

  @recent_events_limit 8

  defp recent_events(identity, sets) do
    sets
    |> Enum.group_by(& &1["event"]["id"])
    |> Enum.map(fn {event_id, event_sets} ->
      our_entrant = find_entrant_id(hd(event_sets), identity["user_id"])

      wins =
        Enum.count(event_sets, fn set ->
          set["winnerId"] != nil and set["winnerId"] == our_entrant
        end)

      completed = Enum.count(event_sets, &(&1["completedAt"] != nil))

      last_played =
        event_sets
        |> Enum.map(& &1["completedAt"])
        |> Enum.reject(&is_nil/1)
        |> Enum.max(fn -> nil end)

      %{
        "event_id" => event_id,
        "name" => hd(event_sets)["event"]["name"],
        "game_slug" => hd(event_sets)["event"]["videogame"]["slug"],
        "sets" => length(event_sets),
        "wins" => wins,
        "losses" => completed - wins,
        "last_played" => last_played
      }
    end)
    |> Enum.sort_by(&{&1["last_played"] || 0}, :desc)
    |> Enum.take(@recent_events_limit)
  end

  defp find_entrant_id(set, user_id) do
    Enum.find_value(set["slots"] || [], fn slot ->
      participants = slot["entrant"]["participants"] || []

      if Enum.any?(participants, fn p -> p["user"] && p["user"]["id"] == user_id end) do
        slot["entrant"]["id"]
      end || nil
    end)
  end

  # A set belongs to the selected game when its event reports that videogame
  # slug. Missing game identity means the set cannot be attributed, so it is
  # excluded from scoped views rather than guessed.
  defp game_matches?(%{"event" => %{"videogame" => %{"slug" => slug}}}, game),
    do: slug == game

  defp game_matches?(_set, _game), do: false

  defp fetch_identity(player_id) do
    case Players.profile(player_id) do
      {:ok, identity, _status} -> {:ok, identity}
      error -> error
    end
  end

  defp fetch_sets(player_id) do
    with {:ok, first} <-
           Client.query_paged(
             fn per_page ->
               Queries.player_sets(player_id, 1, per_page)
             end,
             @sets_per_page
           ) do
      total_pages = min(first["player"]["sets"]["pageInfo"]["totalPages"] || 1, @max_pages)

      rest =
        if total_pages > 1 do
          pages = Enum.to_list(2..total_pages)

          pages
          |> Task.async_stream(
            fn page ->
              Client.query_paged(
                fn per_page ->
                  Queries.player_sets(player_id, page, per_page)
                end,
                @sets_per_page
              )
            end,
            max_concurrency: 5,
            timeout: :infinity,
            ordered: false
          )
          |> Enum.reduce_while({:ok, []}, fn
            {:ok, {:ok, data}}, {:ok, acc} ->
              {:cont, {:ok, [data["player"]["sets"]["nodes"] | acc]}}

            {:ok, {:error, reason}}, _acc ->
              {:halt, {:error, reason}}

            {:error, reason}, _acc ->
              {:halt, {:error, reason}}
          end)
          |> case do
            {:ok, pages} -> {:ok, Enum.reverse(pages)}
            error -> error
          end
        else
          {:ok, []}
        end

      with {:ok, extra_pages} <- rest do
        nodes = first["player"]["sets"]["nodes"]
        {:ok, nodes ++ List.flatten(extra_pages)}
      end
    end
  end
end
