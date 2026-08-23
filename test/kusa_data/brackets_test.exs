defmodule KusaData.BracketsTest do
  use ExUnit.Case, async: false

  use KusaData.Test.Doubles

  alias KusaData.Brackets
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  setup do
    FakeTransport.put(
      :query,
      "EventPhases",
      Fixtures.event_phases_response(100, [
        Fixtures.phase(80, "Finals", [{900, "1"}])
      ])
    )

    :ok
  end

  defp winners_set(id, winner, slots, overrides \\ %{}) do
    Fixtures.bracket_set_node(id, winner, slots, Map.merge(%{"round" => 1}, overrides))
  end

  defp losers_final(id, winner, slots, overrides \\ %{}) do
    Fixtures.bracket_set_node(
      id,
      winner,
      slots,
      Map.merge(%{"round" => -1, "fullRoundText" => "Losers Final"}, overrides)
    )
  end

  test "build splits winners and losers rounds in bracket order" do
    sets = [
      winners_set(1, "11", [
        Fixtures.bracket_slot(11, "Mango"),
        Fixtures.bracket_slot(12, "Armada")
      ]),
      winners_set(
        2,
        "13",
        [
          Fixtures.bracket_slot(13, "Hbox"),
          Fixtures.bracket_slot(14, "Plup")
        ],
        %{"round" => 2, "fullRoundText" => "Winners Final"}
      ),
      losers_final(3, "12", [
        Fixtures.bracket_slot(12, "Armada"),
        Fixtures.bracket_slot(14, "Plup")
      ])
    ]

    %{"groups" => [group]} = Brackets.build([], Enum.map(sets, &Brackets.map_set/1))

    assert group["set_count"] == 3
    assert Enum.map(group["winners_rounds"], & &1["round"]) == [1, 2]
    assert Enum.map(group["losers_rounds"], & &1["round"]) == [-1]
    assert hd(group["winners_rounds"])["name"] == "Winners Round 1"
    assert List.last(group["winners_rounds"])["name"] == "Winners Final"
    assert hd(group["losers_rounds"])["name"] == "Losers Final"
  end

  test "build groups sets by phase group and keeps undeclared groups as fallback pools" do
    phases = [
      %{"id" => 80, "name" => "Finals", "groups" => [%{"id" => 900, "displayIdentifier" => "A"}]}
    ]

    sets = [
      winners_set(1, "11", [
        Fixtures.bracket_slot(11, "Mango"),
        Fixtures.bracket_slot(12, "Armada")
      ]),
      winners_set(
        2,
        "21",
        [
          Fixtures.bracket_slot(21, "Hbox"),
          Fixtures.bracket_slot(22, "Plup")
        ],
        %{
          "phaseGroup" => %{
            "id" => 901,
            "displayIdentifier" => "B",
            "phase" => %{"id" => 81, "name" => "Pools"}
          }
        }
      )
    ]

    %{"groups" => groups} = Brackets.build(phases, Enum.map(sets, &Brackets.map_set/1))

    declared = Enum.find(groups, &(&1["id"] == "900"))
    fallback = Enum.find(groups, &(&1["id"] == "901"))

    assert declared["label"] == "A"
    assert declared["phase"] == "Finals"
    assert fallback["label"] == "B"
    assert fallback["phase"] == "Pools"
    # The undeclared pool's set is not lost; the declared group only has its own.
    assert declared["set_count"] == 1
    assert fallback["set_count"] == 1
  end

  test "run_for orders a player's run chronologically and finds the eliminator" do
    sets = [
      losers_final(
        3,
        "14",
        [Fixtures.bracket_slot(11, "Mango"), Fixtures.bracket_slot(14, "Plup")],
        %{"completedAt" => 100}
      ),
      winners_set(
        1,
        "11",
        [Fixtures.bracket_slot(11, "Mango"), Fixtures.bracket_slot(12, "Armada")],
        %{"completedAt" => 50}
      ),
      winners_set(
        2,
        "13",
        [Fixtures.bracket_slot(11, "Mango"), Fixtures.bracket_slot(13, "Hbox")],
        %{"round" => 2, "fullRoundText" => "Winners Final", "completedAt" => 75}
      )
    ]

    run = Brackets.run_for(Enum.map(sets, &Brackets.map_set/1), "11")

    assert Enum.map(run["sets"], & &1["set_id"]) == ["1", "2", "3"]
    assert Enum.map(run["sets"], & &1["result"]) == ["W", "L", "L"]
    assert Enum.at(run["sets"], 0)["opponent"] == "Armada"
    assert run["eliminator"] == "Plup"
  end

  test "run_for reports nil eliminator for a clean winner run" do
    sets = [
      winners_set(1, "11", [
        Fixtures.bracket_slot(11, "Mango"),
        Fixtures.bracket_slot(12, "Armada")
      ])
    ]

    run = Brackets.run_for(Enum.map(sets, &Brackets.map_set/1), "11")

    assert run["eliminator"] == nil
    assert Enum.count(run["sets"], &(&1["result"] == "W")) == 1
  end

  test "for_event fetches, caches, and clears" do
    FakeTransport.put(
      :query,
      "EventBracketSets",
      Fixtures.bracket_sets_response([
        winners_set(1, "11", [
          Fixtures.bracket_slot(11, "Mango"),
          Fixtures.bracket_slot(12, "Armada")
        ])
      ])
    )

    assert {:ok, brackets, :miss} = Brackets.for_event(100)
    assert [_] = brackets["groups"]

    assert {:ok, ^brackets, :hit} = Brackets.for_event(100)

    :ok = Brackets.clear_cache(100)
    assert {:ok, _brackets, :miss} = Brackets.for_event(100)
  end

  test "for_event reports not_found for unknown events" do
    FakeTransport.put(:query, "EventPhases", %{"data" => %{"event" => nil}})
    FakeTransport.put(:query, "EventBracketSets", %{"data" => %{"event" => nil}})
    assert {:error, :not_found} = Brackets.for_event(404)
  end
end
