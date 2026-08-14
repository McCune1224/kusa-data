defmodule KusaData.GraphQL.Tournaments do
  @moduledoc """
  Hand-written query builders for the seed finder: tournament event listing
  (Melee brackets only) and per-event entrant seeding.
  """

  @doc "Events for a tournament slug matching `videogame_id`."
  @spec tournament_events_query(String.t(), integer) :: {String.t(), map}
  def tournament_events_query(slug, videogame_id) do
    {"""
     query TournamentEvents($slug: String!, $videogameIds: [ID]) {
       tournament(slug: $slug) {
         id
         name
         events(filter: { videogameId: $videogameIds }) {
           id
           name
           slug
         }
       }
     }
     """, %{slug: slug, videogameIds: [videogame_id]}}
  end

  @doc "Entrants with their seed numbers for an event."
  @spec event_seeding_query(integer) :: {String.t(), map}
  def event_seeding_query(event_id) do
    {"""
     query EventSeeding($eventId: ID!) {
       event(id: $eventId) {
         id
         name
         entrants(query: { page: 1, perPage: 500 }) {
           nodes {
             id
             name
             seeds {
               seedNum
             }
           }
         }
       }
     }
     """, %{eventId: event_id}}
  end
end
