defmodule KusaData.SetDetails.API do
  @moduledoc """
  On-demand set detail fetches from start.gg, cached in Redis through
  `KusaData.Cache`. Returns the raw string-keyed payload
  (`{:ok, %{"player" => %{"sets" => ...}}}`) or `{:error, reason}` — callers
  normalize. A Redis outage never fails the fetch; it just goes uncached.
  """

  alias KusaData.Cache
  alias KusaData.GraphQL.{Client, SetDetails}

  @cache_prefix "setDetails"

  @spec for_player(non_neg_integer, pos_integer, pos_integer) :: {:ok, map} | {:error, term}
  def for_player(player_id, page, per_page) do
    key = "#{@cache_prefix}:#{player_id}:#{page}:#{per_page}"

    case Cache.fetch(key, fn -> fetch_uncached(player_id, page, per_page) end) do
      {:ok, data, _status} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_uncached(player_id, page, per_page) do
    case Application.get_env(:kusa_data, __MODULE__, [])[:fetch] do
      fetch when is_function(fetch, 3) ->
        fetch.(player_id, page, per_page)

      _ ->
        {query, variables} = SetDetails.player_sets_query(player_id, page, per_page)
        Client.request(query, variables)
    end
  end
end
