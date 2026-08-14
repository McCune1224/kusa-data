defmodule KusaData.GraphQL.SetDetailsTest do
  use ExUnit.Case, async: true

  alias KusaData.GraphQL.SetDetails

  test "player_sets_query embeds playerId, page and perPage variables" do
    {doc, variables} = SetDetails.player_sets_query(42, 1, 20)
    assert variables == %{playerId: 42, page: 1, perPage: 20}

    assert doc =~ "query PlayerSets"
    assert doc =~ "player(id: $playerId)"
    assert doc =~ "sets(page: $page, perPage: $perPage)"
    assert doc =~ "displayScore"
    assert doc =~ "fullRoundText"
    assert doc =~ "state"
    assert doc =~ "completedAt"
    assert doc =~ "event"
    assert doc =~ "slots"
    assert doc =~ "entrant"
    assert doc =~ "games"
    assert doc =~ "winnerId"
    assert doc =~ "entrant1Score"
    assert doc =~ "entrant2Score"
    assert doc =~ "stage"
    assert doc =~ "selections"
    assert doc =~ "selectionType"
    assert doc =~ "character"
    assert doc =~ "pageInfo"
    assert doc =~ "total"
    assert doc =~ "totalPages"
  end
end
