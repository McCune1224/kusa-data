defmodule KusaData.GraphQL.Queries do
  @moduledoc """
  Hand-written GraphQL query builders for the start.gg API.

  Every document is name-stamped with a unique operation name
  (`NearbyTournaments`, `PlayerSets`, ...) so tests can route fake transport
  responses without parsing the full document.

  Tournament filters take an explicit game selection as a list of start.gg
  `videogameIds` (or `nil` for "all games"), and event payloads carry each
  event's `videogame` identity so callers can normalize and group by game
  without hard-coding numeric ids.
  """

  @spec tournament_search(map(), pos_integer(), pos_integer(), [integer()] | nil) ::
          {String.t(), map()}
  def tournament_search(filter, page, per_page, videogame_ids \\ [1]) do
    {"""
     query TournamentSearch($filter: TournamentPageFilter!, $page: Int!, $perPage: Int!, $videogameIds: [ID]) {
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
           venueAddress
           isRegistrationOpen
           numAttendees
           timezone
           lat
           lng
           events(filter: { videogameId: $videogameIds }) {
             id
             numEntrants
             state
             videogame {
               id
               name
               slug
             }
           }
         }
         pageInfo {
           total
           totalPages
         }
       }
     }
     """,
     %{
       filter: filter,
       page: page,
       perPage: per_page,
       videogameIds: videogame_ids
     }}
  end

  @spec nearby_filter(String.t(), String.t(), [integer()] | nil) :: map()
  def nearby_filter(coordinates, distance, videogame_ids \\ [1]) do
    %{upcoming: true, location: %{distanceFrom: coordinates, distance: distance}}
    |> put_games(videogame_ids)
  end

  @spec upcoming_filter([integer()] | nil) :: map()
  def upcoming_filter(videogame_ids \\ [1]) do
    %{upcoming: true}
    |> put_games(videogame_ids)
  end

  @spec recent_filter(integer(), [integer()] | nil) :: map()
  def recent_filter(after_date, videogame_ids \\ [1]) do
    %{past: true, afterDate: after_date}
    |> put_games(videogame_ids)
  end

  @doc "Filter for a date-bounded past-tournament browse (ISO dates become unix bounds)."
  @spec past_filter(map()) :: map()
  def past_filter(%{from: from, to: to} = query) do
    %{past: true}
    |> maybe_put(:afterDate, iso_to_unix(from))
    |> maybe_put(:beforeDate, iso_to_unix(to))
    |> maybe_put(:countryCode, query[:country])
    |> maybe_put(:state, query[:state])
    |> maybe_put_search(query[:q])
    |> put_games(videogame_ids_for(query))
  end

  defp maybe_put_search(filter, q) when is_binary(q) do
    case String.trim(q) do
      "" -> filter
      trimmed -> Map.put(filter, :search, %{searchString: trimmed})
    end
  end

  defp maybe_put_search(filter, _), do: filter

  @doc "Filter for text search over tournament name, city, and venue."
  @spec search_filter(map()) :: map()
  def search_filter(%{q: q} = query) when is_binary(q) and q != "" do
    %{past: true, search: %{searchString: String.trim(q)}}
    |> put_games(videogame_ids_for(query))
  end

  @doc "Filter for country/state region browsing (state may be omitted)."
  @spec region_filter(map()) :: map()
  def region_filter(%{country: country} = query) when is_binary(country) do
    %{upcoming: true, countryCode: country}
    |> maybe_put(:state, query[:state])
    |> put_games(videogame_ids_for(query))
  end

  @doc "All start.gg videogames, for deriving game records without hard-coded ids."
  @spec videogames() :: {String.t(), map()}
  def videogames do
    {"""
     query Videogames {
       videogames(query: { perPage: 100 }) {
         nodes {
           id
           name
           slug
         }
         pageInfo {
           total
         }
       }
     }
     """, %{}}
  end

  @spec tournament_detail(String.t(), [integer()] | nil) :: {String.t(), map()}
  def tournament_detail(slug, videogame_ids \\ nil) do
    {"""
     query TournamentDetail($slug: String!, $videogameIds: [ID]) {
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
         events(filter: { videogameId: $videogameIds }) {
           id
           name
           slug
           numEntrants
           state
           videogame {
             id
             name
             slug
           }
         }
       }
     }
     """, %{slug: slug, videogameIds: videogame_ids}}
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
         videogame {
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

  @spec event_sets(integer(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def event_sets(event_id, page, per_page) do
    {"""
     query EventSets($id: ID!, $page: Int!, $perPage: Int!) {
       event(id: $id) {
         id
         name
         sets(page: $page, perPage: $perPage) {
           nodes {
             id
             state
             winnerId
             displayScore
             fullRoundText
             completedAt
             slots {
               entrant {
                 id
                 name
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

  @doc """
  Phases and pools (phase groups) for an event, for the bracket view's
  phase/group selector.
  """
  @spec event_phases(integer()) :: {String.t(), map()}
  def event_phases(event_id) do
    {"""
     query EventPhases($id: ID!) {
       event(id: $id) {
         id
         name
         phases {
           id
           name
           phaseGroups(query: { perPage: 100 }) {
             pageInfo {
               total
             }
             nodes {
               id
               displayIdentifier
             }
           }
         }
       }
     }
     """, %{id: event_id}}
  end

  @doc """
  Bracket-aware sets: numeric round (negative = losers side), phase group
  identity, and slot prerequisite links so a bracket tree and player paths
  can be reconstructed client-side.
  """
  @spec event_bracket_sets(integer(), pos_integer(), pos_integer()) :: {String.t(), map()}
  def event_bracket_sets(event_id, page, per_page) do
    {"""
     query EventBracketSets($id: ID!, $page: Int!, $perPage: Int!) {
       event(id: $id) {
         id
         name
         sets(page: $page, perPage: $perPage, sortType: STANDARD) {
           pageInfo {
             total
             totalPages
           }
           nodes {
             id
             state
             winnerId
             displayScore
             fullRoundText
             round
             completedAt
             phaseGroup {
               id
               displayIdentifier
               phase {
                 id
                 name
               }
             }
             slots {
               prereqId
               entrant {
                 id
                 name
               }
             }
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
         prefix
         user {
           id
           name
           bio
           location {
             city
             state
             country
           }
           images(type: "profile") {
             url
           }
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
               videogame {
                 id
                 name
                 slug
               }
             }
             slots {
               entrant {
                 id
                 name
                 participants {
                   user {
                     id
                     player {
                       id
                     }
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

  defp put_games(filter, nil), do: filter
  defp put_games(filter, videogame_ids), do: Map.put(filter, :videogameIds, videogame_ids)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp videogame_ids_for(query) do
    case Map.get(query, :videogame_ids, Map.get(query, :games)) do
      :all -> nil
      nil -> nil
      ids when is_list(ids) -> Enum.map(ids, &numeric_id/1)
      other -> numeric_id(other)
    end
  end

  defp numeric_id(id) when is_integer(id), do: id

  defp numeric_id(id) do
    case Integer.parse(to_string(id)) do
      {number, ""} -> number
      _ -> nil
    end
  end

  @doc "Converts an `YYYY-MM-DD` ISO date (or unix int) to unix seconds, or nil."
  def iso_to_unix(nil), do: nil

  def iso_to_unix(value) when is_integer(value), do: value

  def iso_to_unix(iso) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()
      _ -> nil
    end
  end

  def iso_to_unix(_), do: nil

  defp numeric_or_nil(nil), do: nil
  defp numeric_or_nil(identifier) when is_integer(identifier), do: identifier

  defp numeric_or_nil(identifier) when is_binary(identifier) do
    case Integer.parse(identifier) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp numeric_or_nil(_), do: nil

  defp slug_or_nil(identifier) do
    case numeric_or_nil(identifier) do
      nil -> identifier
      _ -> nil
    end
  end
end
