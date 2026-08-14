defmodule KusaData.GraphQL.Crawl do
  @moduledoc """
  Pure, hand-written GraphQL query builders for the rankings crawler, mirroring
  the old TypeScript queries. Each returns `{query, variables}` for the
  `KusaData.GraphQL.Client`.

  No I/O here — the document strings are deterministic so the crawler's HTTP
  layer can be unit-tested against Bypass.
  """

  @spec event_sets_query(pos_integer, pos_integer, pos_integer) :: {String.t(), map}
  def event_sets_query(event_id, page, per_page) do
    query = """
    query EventSets($eventId: ID!, $page: Int!, $perPage: Int!) {
      event(id: $eventId) {
        id
        name
        sets(page: $page, perPage: $perPage) {
          pageInfo {
            total
            totalPages
          }
          nodes {
            id
            state
            completedAt
            slots {
              entrant {
                id
                participants {
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
              standing {
                stats {
                  score {
                    value
                  }
                }
              }
            }
          }
        }
      }
    }
    """

    {query, %{eventId: event_id, page: page, perPage: per_page}}
  end

  @spec tournament_pool_query(pos_integer, integer, pos_integer, pos_integer, integer | nil) ::
          {String.t(), map}
  def tournament_pool_query(videogame_id, after_date, per_page, page, before_date \\ nil) do
    query = """
    query RankingsTournamentPool(
      $afterDate: Timestamp
      $beforeDate: Timestamp
      $perPage: Int
      $page: Int
      $videogameIds: [ID]!
    ) {
      tournaments(
        query: {
          perPage: $perPage
          page: $page
          filter: {
            videogameIds: $videogameIds
            past: true
            afterDate: $afterDate
            beforeDate: $beforeDate
          }
        }
      ) {
        nodes {
          id
          slug
        }
      }
    }
    """

    {query,
     %{
       afterDate: after_date,
       beforeDate: before_date,
       perPage: per_page,
       page: page,
       videogameIds: [videogame_id]
     }}
  end

  @spec game_event_query(String.t(), pos_integer) :: {String.t(), map}
  def game_event_query(tournament_slug, videogame_id) do
    query = """
    query RankingsGameEvent($tournamentSlug: String!, $videogameIds: [ID]!) {
      tournament(slug: $tournamentSlug) {
        events(filter: { videogameId: $videogameIds }) {
          id
          name
        }
      }
    }
    """

    {query, %{tournamentSlug: tournament_slug, videogameIds: [videogame_id]}}
  end
end
