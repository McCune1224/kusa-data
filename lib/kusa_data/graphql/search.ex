defmodule KusaData.GraphQL.Search do
  @moduledoc """
  Pure, hand-written GraphQL query builders for player search's *live fallback*:
  scanning recent tournament participants (start.gg has no global user search —
  the only name-searchable connection is a tournament's participants).
  """

  @spec recent_tournament_pool_query(integer, pos_integer) :: {String.t(), map}
  def recent_tournament_pool_query(after_date, per_page) do
    query = """
    query RecentTournaments($afterDate: Timestamp, $perPage: Int) {
      tournaments(
        query: {
          perPage: $perPage
          page: 1
          filter: { videogameIds: [1], past: true, afterDate: $afterDate }
        }
      ) {
        nodes {
          slug
        }
      }
    }
    """

    {query, %{afterDate: after_date, perPage: per_page}}
  end

  @spec participant_search_query(String.t(), String.t(), pos_integer) :: {String.t(), map}
  def participant_search_query(tournament_slug, search_string, per_page) do
    query = """
    query SearchParticipants($tournamentSlug: String!, $searchString: String!, $perPage: Int!) {
      tournament(slug: $tournamentSlug) {
        participants(
          query: {
            perPage: $perPage
            filter: {
              search: { fieldsToSearch: ["gamerTag", "prefix"], searchString: $searchString }
            }
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
        }
      }
    }
    """

    {query, %{tournamentSlug: tournament_slug, searchString: search_string, perPage: per_page}}
  end
end
