defmodule KusaData.Stats do
  @moduledoc """
  On-demand player stats.

  Fetches the player's recent set history (capped at `@max_pages` pages so a
  top player's 1,500+ sets don't wreck the response budget), computes stats
  with `KusaData.Stats.Engine`, and caches the result per player.
  """

  @sets_per_page 50
  @max_pages 6
  @cache_ttl 15 * 60

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries
  alias KusaData.Players
  alias KusaData.Stats.Engine

  @spec for_player(integer()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def for_player(player_id) do
    Cache.fetch("player:#{player_id}:stats", @cache_ttl, fn -> compute(player_id) end)
  end

  @doc "Drops the cached stats so the next fetch is fresh."
  @spec clear_cache(integer()) :: :ok
  def clear_cache(player_id) do
    Cache.delete("player:#{player_id}:stats")
    :ok
  end

  defp compute(player_id) do
    with {:ok, identity} <- fetch_identity(player_id) do
      with {:ok, sets} <- fetch_sets(player_id) do
        {:ok, Engine.build(identity, sets)}
      end
    end
  end

  defp fetch_identity(player_id) do
    case Players.profile(player_id) do
      {:ok, identity, _status} -> {:ok, identity}
      error -> error
    end
  end

  defp fetch_sets(player_id) do
    with {:ok, first} <- Client.query(Queries.player_sets(player_id, 1, @sets_per_page)) do
      total_pages = min(first["player"]["sets"]["pageInfo"]["totalPages"] || 1, @max_pages)

      rest =
        if total_pages > 1 do
          pages = Enum.to_list(2..total_pages)

          pages
          |> Task.async_stream(
            fn page -> Client.query(Queries.player_sets(player_id, page, @sets_per_page)) end,
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
