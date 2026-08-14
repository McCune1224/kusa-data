defmodule KusaData.GraphQL.CrawlTest do
  use ExUnit.Case, async: true

  alias KusaData.GraphQL.Crawl

  test "event_sets_query embeds eventId, page and perPage variables" do
    {doc, variables} = Crawl.event_sets_query(123, 2, 50)
    assert variables == %{eventId: 123, page: 2, perPage: 50}

    assert doc =~ "query EventSets"
    assert doc =~ "sets(page: $page, perPage: $perPage)"
    assert doc =~ "completedAt"
    assert doc =~ "gamerTag"
    assert doc =~ "prefix"
    assert doc =~ "player"
  end

  test "tournament_pool_query embeds videogame and window variables" do
    {doc, variables} = Crawl.tournament_pool_query(1, 1_700_000_000, 30, 1, 1_700_604_800)

    assert variables == %{
             afterDate: 1_700_000_000,
             beforeDate: 1_700_604_800,
             perPage: 30,
             page: 1,
             videogameIds: [1]
           }

    assert doc =~ "query RankingsTournamentPool"
    assert doc =~ "videogameIds"
    assert doc =~ "afterDate"
    assert doc =~ "beforeDate"
  end

  test "game_event_query embeds tournament slug and videogame" do
    {doc, variables} = Crawl.game_event_query("/tournament/foo", 1)
    assert variables == %{tournamentSlug: "/tournament/foo", videogameIds: [1]}
    assert doc =~ "query RankingsGameEvent"
    assert doc =~ "tournament(slug: $tournamentSlug)"
    assert doc =~ "events(filter: { videogameId: $videogameIds })"
  end
end
