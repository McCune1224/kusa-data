defmodule KusaData.Rankings do
  @moduledoc """
  Region/game/season power rankings backed by the Elo engine.

  Scope filters: `game` (slug), `country`/`state`, and `from`/`to` (unix
  bounds). Tournaments are collected from the shared browse contract, their
  entrants become the candidate pool (each player's set history fetched
  through `Stats.raw_sets/2` with the same per-game scoping as the player
  pages), and `Rankings.Engine.compute/2` produces the deterministic table.
  Results are cached under the full parameter set.
  """

  @ttl 15 * 60
  @max_tournaments 40
  @max_players 100

  alias KusaData.Cache
  alias KusaData.Events
  alias KusaData.Players
  alias KusaData.Rankings.Engine
  alias KusaData.Stats
  alias KusaData.Tournaments

  @doc """
  Computes (or serves from cache) a ranking for the given scope.

  Returns `%{"rankings" => [...], "tournaments" => n, "players_scanned" => n,
  "params" => %{...}}`.
  """
  @spec rank(map()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def rank(opts \\ %{}) do
    opts = normalize_opts(opts)
    Cache.fetch(rank_key(opts), @ttl, fn -> compute_rank(opts) end)
  end

  defp compute_rank(opts) do
    with {:ok, tournaments} <- scope_tournaments(opts),
         {:ok, player_ids} <- candidate_players(tournaments, opts),
         {:ok, players_sets} <- fetch_player_sets(player_ids, opts) do
      rankings = Engine.compute(players_sets, k: opts.k, min_tournaments: opts.min_tournaments)

      {:ok,
       %{
         "rankings" => rankings,
         "tournaments" => length(tournaments),
         "players_scanned" => length(player_ids),
         "params" => opts
       }}
    end
  end

  defp normalize_opts(opts) do
    %{
      game: opts[:game],
      country: opts[:country],
      state: opts[:state],
      from: opts[:from],
      to: opts[:to],
      k: opts[:k] || 32,
      min_tournaments: opts[:min_tournaments] || 3
    }
  end

  defp rank_key(opts) do
    canonical =
      %{
        "game" => opts.game,
        "country" => opts.country,
        "state" => opts.state,
        "from" => opts.from,
        "to" => opts.to,
        "k" => opts.k,
        "min_tournaments" => opts.min_tournaments
      }
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    "rankings:#{canonical}"
  end

  defp scope_tournaments(opts) do
    collect_tournaments(opts, 1, [])
  end

  defp collect_tournaments(opts, page, acc) do
    query = %{
      mode: :past,
      country: opts.country,
      state: opts.state,
      from: opts.from,
      to: opts.to,
      results_only: true,
      games: if(opts.game, do: [opts.game], else: :all),
      page: page
    }

    case Tournaments.browse(query) do
      {:ok, data, _} ->
        nodes = data["tournaments"] || []
        acc = acc ++ nodes

        cond do
          length(acc) >= @max_tournaments -> {:ok, Enum.take(acc, @max_tournaments)}
          nodes == [] -> {:ok, acc}
          true -> collect_tournaments(opts, page + 1, acc)
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp candidate_players(tournaments, _opts) do
    events = Enum.flat_map(tournaments, &(&1["events"] || []))

    events
    |> Enum.reduce_while({:ok, MapSet.new()}, fn event, {:ok, acc} ->
      case Events.analytics(event["id"]) do
        {:ok, data, _} ->
          ids =
            data["analysis"]["entrants"]
            |> Enum.map(& &1["player_id"])
            |> Enum.reject(&is_nil/1)
            |> MapSet.new()

          acc = MapSet.union(acc, ids)

          if MapSet.size(acc) >= @max_players do
            {:halt, {:ok, Enum.take(MapSet.to_list(acc), @max_players)}}
          else
            {:cont, {:ok, acc}}
          end

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.take(Enum.sort(ids), @max_players)}
      error -> error
    end
  end

  defp fetch_player_sets(player_ids, opts) do
    player_ids
    |> Task.async_stream(
      fn player_id ->
        with {:ok, sets, _} <- Stats.raw_sets(player_id, opts.game),
             {:ok, identity, _} <- Players.profile(player_id) do
          {player_id, %{"gamer_tag" => identity["gamer_tag"], "sets" => sets}}
        else
          _ -> {player_id, %{"gamer_tag" => nil, "sets" => []}}
        end
      end,
      max_concurrency: 8,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.reduce_while({:ok, %{}}, fn
      {:ok, {player_id, data}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, player_id, data)}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
  end
end
