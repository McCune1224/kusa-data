defmodule KusaData.GraphQL.Queries do
  @moduledoc """
  Hand-written GraphQL query builders for the start.gg API.

  Every document is name-stamped with a unique operation name
  (`NearbyTournaments`, `PlayerSets`, ...) so tests can route fake transport
  responses without parsing the full document.
  """

  @spec tournament_search(map(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def tournament_search(filter, page, per_page) do
    {"""
     query TournamentSearch($filter: TournamentPageFilter!, $page: Int!, $perPage: Int!) {
       tournaments(query: { page: $page, perPage: $perPage, filter: $filter }) {
         nodes {
           id
           name
           slug
           city
           addrState
           countryCode
           startAt
           endAt
           venueName
           isRegistrationOpen
           numAttendees
           timezone
           lat
           lng
           events(filter: { videogameId: [1] }) {
             id
             numEntrants
           }
         }
         pageInfo {
           total
           totalPages
         }
       }
     }
     """, %{filter: filter, page: page, perPage: per_page}}
  end

  @spec nearby_filter(String.t(), String.t()) :: map()
  def nearby_filter(coordinates, distance) do
    %{
      upcoming: true,
      videogameIds: [1],
      location: %{distanceFrom: coordinates, distance: distance}
    }
  end

  @spec upcoming_filter() :: map()
  def upcoming_filter do
    %{upcoming: true, videogameIds: [1]}
  end

  @spec recent_filter(integer()) :: map()
  def recent_filter(after_date) do
    %{past: true, videogameIds: [1], afterDate: after_date}
  end

  @spec tournament_detail(String.t()) :: {String.t(), map()}
  def tournament_detail(slug) do
    {"""
     query TournamentDetail($slug: String!) {
       tournament(slug: $slug) {
         id
         name
         slug
         city
         addrState
         countryCode
         startAt
         endAt
         venueName
         venueAddress
         timezone
         isRegistrationOpen
         numAttendees
         events(filter: { videogameId: [1] }) {
           id
           name
           slug
           numEntrants
           state
         }
       }
     }
     """, %{slug: slug}}
  end

  @spec event_detail(integer() | String.t()) :: {String.t(), map()}
  def event_detail(identifier) do
    {"""
     query EventDetail($id: ID, $slug: String) {
       event(id: $id, slug: $slug) {
         id
         name
         slug
         numEntrants
         state
         tournament {
           id
           name
           slug
         }
       }
     }
     """, %{id: numeric_or_nil(identifier), slug: slug_or_nil(identifier)}}
  end

  @spec event_seeding(integer(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def event_seeding(event_id, page, per_page) do
    {"""
     query EventSeeding($id: ID!, $page: Int!, $perPage: Int!) {
       event(id: $id) {
         id
         name
         entrants(query: { page: $page, perPage: $perPage }) {
           nodes {
             id
             name
             seeds {
               seedNum
             }
             participants {
               user {
                 player {
                   id
                 }
               }
             }
           }
           pageInfo {
             total
             totalPages
           }
         }
       }
     }
     """, %{id: event_id, page: page, perPage: per_page}}
  end

  @spec event_results(integer(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def event_results(event_id, page, per_page) do
    {"""
     query EventResults($id: ID!, $page: Int!, $perPage: Int!) {
       event(id: $id) {
         id
         name
         standings(query: { page: $page, perPage: $perPage }) {
           nodes {
             placement
             entrant {
               id
               name
               participants {
                 user {
                   player {
                     id
                   }
                 }
               }
             }
           }
           pageInfo {
             total
             totalPages
           }
         }
       }
     }
     """, %{id: event_id, page: page, perPage: per_page}}
  end

  @spec participant_search(String.t(), String.t(), pos_integer()) :: {String.t(), map()}
  def participant_search(tournament_slug, search_string, per_page) do
    {"""
     query TournamentParticipants($slug: String!, $searchString: String!, $perPage: Int!) {
       tournament(slug: $slug) {
         participants(
           query: {
             perPage: $perPage
             filter: { search: { searchString: $searchString, fieldsToSearch: ["gamerTag", "prefix"] } }
           }
         ) {
           nodes {
             id
             gamerTag
             prefix
             user {
               id
               player {
                 id
               }
             }
           }
           pageInfo {
             total
           }
         }
       }
     }
     """, %{slug: tournament_slug, searchString: search_string, perPage: per_page}}
  end

  @spec player_identity(integer()) :: {String.t(), map()}
  def player_identity(player_id) do
    {"""
     query PlayerIdentity($id: ID!) {
       player(id: $id) {
         id
         gamerTag
         user {
           id
         }
       }
     }
     """, %{id: player_id}}
  end

  @spec player_sets(integer(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def player_sets(player_id, page, per_page) do
    {"""
     query PlayerSets($id: ID!, $page: Int!, $perPage: Int!) {
       player(id: $id) {
         id
         gamerTag
         sets(page: $page, perPage: $perPage) {
           nodes {
             id
             state
             winnerId
             displayScore
             fullRoundText
             completedAt
             event {
               id
               name
             }
             slots {
               entrant {
                 id
                 name
                 participants {
                   user {
                     id
                   }
                 }
               }
             }
             games {
               winnerId
               stage {
                 id
                 name
               }
               selections {
                 entrant {
                   id
                 }
                 selectionType
                 character {
                   id
                   name
                 }
               }
             }
           }
           pageInfo {
             total
             totalPages
           }
         }
       }
     }
     """, %{id: player_id, page: page, perPage: per_page}}
  end

  defp numeric_or_nil(identifier) when is_integer(identifier), do: identifier

  defp numeric_or_nil(identifier) do
    case Integer.parse(identifier) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp slug_or_nil(identifier) do
    case numeric_or_nil(identifier) do
      nil -> identifier
      _ -> nil
    end
  end
end
