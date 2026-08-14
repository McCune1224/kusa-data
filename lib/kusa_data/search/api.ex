defmodule KusaData.Search.API do
  @moduledoc """
  HTTP layer for player search's live start.gg fallback.

  start.gg has no global user search — the only name-searchable connection is a
  tournament's participants. So we pull the slugs of recent past Melee
  tournaments, then scan each one's participants for a gamer-tag/prefix match.
  All I/O flows through the shared rate-limited client; failures degrade to
  `{:ok, []}` so a flaky tournament never breaks a search.
  """

  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Search

  @doc "Slugs of the `per_page` most recent past Melee tournaments after `after_date`."
  @spec recent_tournaments(integer, pos_integer) :: {:ok, [String.t()]} | {:error, term}
  def recent_tournaments(after_date, per_page) do
    {query, vars} = Search.recent_tournament_pool_query(after_date, per_page)

    with {:ok, data} <- Client.request(query, vars) do
      nodes = get_in(data, ["tournaments", "nodes"]) || []
      {:ok, Enum.map(nodes, & &1["slug"])}
    end
  end

  @doc """
  Participants in `tournament_slug` matching `search_string` (searches gamerTag
  + prefix, start.gg's own fuzzy match). Never raises and never blocks a search:
  a missing tournament or any HTTP/GraphQL failure yields `{:ok, []}`.
  """
  @spec search_participants(String.t(), String.t(), pos_integer) :: {:ok, [map]}
  def search_participants(tournament_slug, search_string, per_page) do
    {query, vars} = Search.participant_search_query(tournament_slug, search_string, per_page)

    case Client.request(query, vars) do
      {:ok, data} ->
        nodes = get_in(data, ["tournament", "participants", "nodes"]) || []

        {:ok,
         Enum.map(nodes, fn node ->
           user = node["user"] || %{}

           %{
             user_id: user["id"],
             gamer_tag: node["gamerTag"],
             prefix: node["prefix"],
             player_id: get_in(user, ["player", "id"])
           }
         end)}

      {:error, _reason} ->
        {:ok, []}
    end
  end
end
