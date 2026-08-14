defmodule KusaData.Crawl.API do
  @moduledoc """
  HTTP layer for the rankings crawler — wraps the pure query builders from
  `KusaData.GraphQL.Crawl` and the start.gg client. Returns plain maps/structs
  the crawler can reason about; all I/O goes through the client (rate-limited,
  retried). Never touches the database — persistence is the crawler's job.
  """

  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Crawl

  @doc "Tournament pool for a videogame within a window."
  @spec get_pool(pos_integer, integer, pos_integer, pos_integer, integer | nil) ::
          {:ok, [%{id: integer, slug: String.t()}]} | {:error, term}
  def get_pool(videogame_id, after_date, per_page, page, before_date) do
    {query, vars} =
      Crawl.tournament_pool_query(videogame_id, after_date, per_page, page, before_date)

    with {:ok, data} <- Client.request(query, vars) do
      nodes = get_in(data, ["tournaments", "nodes"]) || []
      {:ok, Enum.map(nodes, fn n -> %{id: n["id"], slug: n["slug"]} end)}
    end
  end

  @doc """
  The event for `tournament_slug` matching `videogame_id`, preferring the
  singles bracket (doubles/crew must never be scored against a singles
  leaderboard). Returns `:error` when the tournament has no such event.
  """
  @spec get_game_event(String.t(), pos_integer) :: {:ok, integer} | :error
  def get_game_event(tournament_slug, videogame_id) do
    {query, vars} = Crawl.game_event_query(tournament_slug, videogame_id)

    with {:ok, data} <- Client.request(query, vars) do
      events = get_in(data, ["tournament", "events"]) || []

      case pick_singles(events) do
        :error -> :error
        {:ok, event_id} -> {:ok, event_id}
      end
    end
  end

  # Prefers the singles bracket; falls back to the first event when there is no
  # match. Returns :error when the tournament has no matching events at all.
  defp pick_singles([]), do: :error

  defp pick_singles(events) do
    singles = Enum.find(events, fn e -> e["name"] =~ ~r/singles/i end)
    {:ok, (singles || hd(events))["id"]}
  end

  @doc "Paginated completed set nodes for an event."
  @spec get_event_sets(pos_integer, pos_integer, pos_integer) ::
          {:ok, [map], non_neg_integer} | {:error, term}
  def get_event_sets(event_id, page, per_page) do
    {query, vars} = Crawl.event_sets_query(event_id, page, per_page)

    with {:ok, data} <- Client.request(query, vars) do
      case get_in(data, ["event"]) do
        nil ->
          {:ok, [], 0}

        event ->
          sets = get_in(event, ["sets"]) || %{}
          total_pages = get_in(sets, ["pageInfo", "totalPages"]) || 0
          nodes = get_in(sets, ["nodes"]) || []
          {:ok, nodes, total_pages}
      end
    end
  end
end
