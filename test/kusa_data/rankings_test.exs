defmodule KusaData.RankingsTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Rankings
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    tournament =
      Fixtures.tournament(1, %{
        "slug" => "tournament/test-melee-weekly",
        "events" => [%{"id" => 100, "numEntrants" => 32, "state" => 3}]
      })

    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([tournament], 1)
    )

    FakeTransport.put(:query, "TournamentDetail", Fixtures.tournament_detail_response(tournament))
    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(Fixtures.event(100)))

    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([
        Fixtures.entrant(11, "Mango", 1, 100),
        Fixtures.entrant(12, "Armada", 2, 200)
      ])
    )

    FakeTransport.put(
      :query,
      "EventResults",
      Fixtures.results_response([
        Fixtures.standing(11, "Mango", 1, 100),
        Fixtures.standing(12, "Armada", 2, 200)
      ])
    )

    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([Fixtures.event_set(1, 11, [11, 12])])
    )

    FakeTransport.put(:query, "PlayerIdentity", fn
      1 -> Fixtures.player_identity_response(100, "Mango", 10)
      _ -> Fixtures.player_identity_response(200, "Armada", 20)
    end)

    # Both players have sets across 3+ events so they meet the tournament floor.
    sets =
      Enum.flat_map(100..102, fn event_id ->
        event = %{
          "id" => event_id,
          "name" => "E#{event_id}",
          "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
        }

        [
          Fixtures.set(1, 1, 2, 1, %{"event" => event}),
          Fixtures.set(2, 1, 2, 2, %{"event" => event}),
          Fixtures.set(3, 1, 2, 1, %{"event" => event})
        ]
      end)

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response(sets))
    :ok
  end

  test "rank computes Elo ratings for region-scoped eligible players" do
    assert {:ok, data, :miss} = Rankings.rank(%{country: "US", state: "IL", game: "melee"})

    assert [first, second] = data["rankings"]
    assert first["rating"] > second["rating"]
    assert first["tournaments"] == 3
    assert data["tournaments"] == 1
    assert data["players_scanned"] == 2
  end

  test "rank caches by the full parameter set" do
    assert {:ok, _, :miss} = Rankings.rank(%{country: "US", state: "IL"})
    assert {:ok, _, :hit} = Rankings.rank(%{country: "US", state: "IL"})
    assert {:ok, _, :miss} = Rankings.rank(%{country: "US", state: "CA"})
    assert {:ok, _, :miss} = Rankings.rank(%{country: "US", state: "IL", min_tournaments: 5})
  end
end
