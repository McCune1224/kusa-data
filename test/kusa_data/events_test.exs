defmodule KusaData.EventsTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Events
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(Fixtures.event(100)))
    :ok
  end

  test "get resolves numeric ids and full slugs" do
    assert {:ok, event, :miss} = Events.get("100")
    assert event["name"] == "Melee Singles"
    assert event["tournament"]["slug"] == "tournament/test-melee-weekly"
  end

  test "get reports not_found for missing events" do
    FakeTransport.put(:query, "EventDetail", %{"data" => %{"event" => nil}})
    assert {:error, :not_found} = Events.get("999")
  end

  test "seeding returns entrants sorted by seed" do
    entrants = [
      Fixtures.entrant(1, "Zed", 2, 502),
      Fixtures.entrant(2, "Alpha", 1, 501),
      Fixtures.entrant(3, "Mid", 3)
    ]

    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response(entrants))

    assert {:ok, seeds, :miss} = Events.seeding(100)
    assert Enum.map(seeds, & &1["seed"]) == [1, 2, 3]
    assert Enum.map(seeds, & &1["name"]) == ["Alpha", "Zed", "Mid"]
    assert hd(seeds)["id"] == 2
    assert hd(seeds)["player_id"] == 501
    assert Enum.at(seeds, 1)["player_id"] == 502
    assert Enum.at(seeds, 2)["player_id"] == nil
  end

  test "seeding fetches and merges multiple pages" do
    page_1 = [Fixtures.entrant(1, "One", 1), Fixtures.entrant(2, "Two", 2)]
    page_2 = [Fixtures.entrant(3, "Three", 3)]

    FakeTransport.put(:query, "EventSeeding", fn
      1 ->
        %{
          "data" => %{
            "event" => %{
              "id" => 100,
              "name" => "Melee Singles",
              "entrants" => %{"nodes" => page_1, "pageInfo" => %{"total" => 3, "totalPages" => 2}}
            }
          }
        }

      2 ->
        %{
          "data" => %{
            "event" => %{
              "id" => 100,
              "name" => "Melee Singles",
              "entrants" => %{"nodes" => page_2, "pageInfo" => %{"total" => 3, "totalPages" => 2}}
            }
          }
        }
    end)

    assert {:ok, seeds, :miss} = Events.seeding(100)
    assert length(seeds) == 3
    assert Enum.map(seeds, & &1["seed"]) == [1, 2, 3]
  end

  test "results returns standings sorted by placement" do
    standings = [
      Fixtures.standing(3, "Third", 3),
      Fixtures.standing(1, "First", 1, 601),
      Fixtures.standing(2, "Second", 2, 602)
    ]

    FakeTransport.put(:query, "EventResults", Fixtures.results_response(standings))

    assert {:ok, results, :miss} = Events.results(100)
    assert Enum.map(results, & &1["placement"]) == [1, 2, 3]
    assert Enum.map(results, & &1["name"]) == ["First", "Second", "Third"]
    assert hd(results)["player_id"] == 601
    assert Enum.at(results, 1)["player_id"] == 602
    assert Enum.at(results, 2)["player_id"] == nil
  end

  test "clear_cache forces fresh fetches" do
    entrants = [Fixtures.entrant(1, "First", 1)]
    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response(entrants))

    assert {:ok, _, :miss} = Events.seeding(100)
    assert {:ok, _, :hit} = Events.seeding(100)

    :ok = Events.clear_cache(100)

    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response([]))
    assert {:ok, [], :miss} = Events.seeding(100)
  end

  test "sets returns normalized set rows with entrant ids" do
    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([
        Fixtures.event_set(1, 11, [11, 12]),
        Fixtures.event_set(2, 12, [11, 12], %{"displayScore" => "0 - 3"})
      ])
    )

    assert {:ok, rows, :miss} = Events.sets(100)
    assert length(rows) == 2
    assert hd(rows)["winner_id"] == 11
    assert hd(rows)["display_score"] == "3 - 1"

    assert hd(rows)["slots"] == [
             %{"entrant_id" => 11, "name" => "Entrant 11"},
             %{"entrant_id" => 12, "name" => "Entrant 12"}
           ]
  end

  test "analytics joins seeds, results, and sets through the bracket engine" do
    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([Fixtures.entrant(11, "Mango", 1, 501)])
    )

    FakeTransport.put(
      :query,
      "EventResults",
      Fixtures.results_response([Fixtures.standing(11, "Mango", 1, 501)])
    )

    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([Fixtures.event_set(1, 11, [11, 12])])
    )

    assert {:ok, data, :miss} = Events.analytics(100)
    assert data["analysis"]["entrant_count"] == 2
    assert data["analysis"]["match_count"] == 1
  end
end
