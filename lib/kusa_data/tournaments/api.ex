defmodule KusaData.Tournaments.API do
  @moduledoc """
  Seed-finder reads from start.gg, cached in Redis through `KusaData.Cache`.
  Returns normalized maps (atom keys) built from raw string-keyed payloads.

  A configurable `:fetch` hook (`config :kusa_data, KusaData.Tournaments.API,
  fetch: fn query, variables -> {:ok, payload} end`) lets tests bypass HTTP
  entirely.
  """

  alias KusaData.Cache
  alias KusaData.GraphQL.{Client, Tournaments}

  @events_ttl 300
  @seeding_ttl 300

  @doc """
  Melee events for a tournament. Returns
  `{:ok, %{id:, name:, events: [%{id:, name:, slug:}]}}` or `{:error, reason}`.
  """
  @spec events(String.t(), integer) :: {:ok, map} | {:error, term}
  def events(slug, videogame_id) do
    {query, variables} = Tournaments.tournament_events_query(slug, videogame_id)

    case fetch_cached("tournamentEvents:#{videogame_id}:#{slug}", query, variables, @events_ttl) do
      {:ok, payload} -> normalize_events(payload)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Seeded entrants for an event. Returns
  `{:ok, %{id:, name:, entrants: [%{id:, name:, seed_nums: [integer]}]}}`
  sorted by lowest seed first, or `{:error, reason}`.
  """
  @spec seeding(integer) :: {:ok, map} | {:error, term}
  def seeding(event_id) do
    {query, variables} = Tournaments.event_seeding_query(event_id)

    case fetch_cached("eventSeeding:#{event_id}", query, variables, @seeding_ttl) do
      {:ok, payload} -> normalize_seeding(payload)
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_cached(key, query, variables, ttl) do
    case Cache.fetch(key, ttl, fn -> request(query, variables) end) do
      {:ok, payload, _status} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(query, variables) do
    case Application.get_env(:kusa_data, __MODULE__, [])[:fetch] do
      fetch when is_function(fetch, 2) -> fetch.(query, variables)
      _ -> Client.request(query, variables)
    end
  end

  defp normalize_events(payload) do
    case payload["tournament"] do
      nil ->
        {:error, :tournament_not_found}

      tournament ->
        events =
          tournament
          |> get_in(["events"]) || []

        {:ok,
         %{
           id: tournament["id"],
           name: tournament["name"],
           events:
             Enum.map(events, fn event ->
               %{id: event["id"], name: event["name"], slug: event["slug"]}
             end)
         }}
    end
  end

  defp normalize_seeding(payload) do
    case payload["event"] do
      nil ->
        {:error, :event_not_found}

      event ->
        entrants =
          (get_in(event, ["entrants", "nodes"]) || [])
          |> Enum.map(fn entrant ->
            seed_nums =
              entrant
              |> get_in(["seeds"]) || []

            %{
              id: entrant["id"],
              name: entrant["name"],
              seed_nums:
                seed_nums |> Enum.map(& &1["seedNum"]) |> Enum.reject(&is_nil/1) |> Enum.sort()
            }
          end)
          |> Enum.sort_by(fn entrant -> List.first(entrant.seed_nums, [9999]) end)

        {:ok, %{id: event["id"], name: event["name"], entrants: entrants}}
    end
  end
end
