defmodule KusaData.Rankings.EngineTest do
  use ExUnit.Case, async: true

  alias KusaData.Rankings.Engine
  alias KusaData.Test.Fixtures

  @now 1_800_000_000

  defp set(id, winner_id, completed_at, our_entrant, their_entrant) do
    Fixtures.set(id, our_entrant, their_entrant, winner_id, %{
      "completedAt" => completed_at,
      "slots" => [
        Fixtures.slot(our_entrant, "P#{our_entrant}", our_entrant * 10, our_entrant),
        Fixtures.slot(their_entrant, "P#{their_entrant}", their_entrant * 10, their_entrant)
      ]
    })
  end

  defp players(specs) do
    Map.new(specs, fn {id, {tag, sets}} -> {id, %{"gamer_tag" => tag, "sets" => sets}} end)
  end

  test "a player beating a stronger opponent gains rating; loser loses" do
    # P1 beats P2 (both at 1500). P1 must gain, P2 must lose, sum preserved.
    sets = [
      set(1, 1, @now - 86_400, 1, 2),
      set(2, 2, @now - 43_200, 1, 2),
      set(3, 1, @now - 10_000, 1, 2)
    ]

    # Both players need >= 3 tournaments: give each 3 distinct events.
    sets =
      Enum.flat_map(1..3, fn i ->
        Enum.map(sets, fn s ->
          event = %{"id" => 100 + i, "name" => "Event #{i}"}
          Map.put(s, "event", event)
        end)
      end)

    rankings = Engine.compute(players(%{1 => {"Mango", sets}, 2 => {"Armada", sets}}), now: @now)

    by_id = Map.new(rankings, &{&1["player_id"], &1})
    assert by_id[1]["rating"] > 1500
    assert by_id[2]["rating"] < 1500
    # Elo conserves the total across the two players.
    assert by_id[1]["rating"] + by_id[2]["rating"] == 3000
    # Sets are deduped across both players' histories (one row per set id).
    assert by_id[1]["matches"] == 3
  end

  test "chronological processing means late results move ratings" do
    # P1 loses early, then wins a lot: final rating above P2.
    early = Enum.map(1..5, fn i -> set(i, 2, @now - 100_000 + i, 1, 2) end)
    late = Enum.map(6..10, fn i -> set(i, 1, @now - 10_000 + i, 1, 2) end)

    sets = (early ++ late) |> give_events()

    rankings = Engine.compute(players(%{1 => {"Mango", sets}, 2 => {"Armada", sets}}), now: @now)
    by_id = Map.new(rankings, &{&1["player_id"], &1})
    assert by_id[1]["rating"] > by_id[2]["rating"]
  end

  test "ties (equal ratings) yield expected score 0.5 and no movement without wins" do
    sets =
      [
        set(1, 1, @now - 86_400, 1, 2),
        set(2, 2, @now - 43_200, 1, 2),
        set(3, 1, @now - 10_000, 1, 2),
        set(4, 2, @now - 5_000, 1, 2)
      ]
      |> give_events()

    rankings = Engine.compute(players(%{1 => {"Mango", sets}, 2 => {"Armada", sets}}), now: @now)
    by_id = Map.new(rankings, &{&1["player_id"], &1})
    # Equal wins/losses keeps ratings near the start; Elo conserves the total.
    assert abs(by_id[1]["rating"] - 1500) < 20
    assert by_id[1]["rating"] + by_id[2]["rating"] == 3000
    assert by_id[1]["matches"] == 4
  end

  test "players below the tournament floor are excluded" do
    # P1 has 1 tournament, P2 has 3.
    one = [set(1, 1, @now - 86_400, 1, 2)] |> give_events()

    three =
      [
        set(1, 1, @now - 86_400, 1, 2),
        set(2, 2, @now - 43_200, 1, 2),
        set(3, 1, @now - 10_000, 1, 2)
      ]
      |> give_events()

    rankings = Engine.compute(players(%{1 => {"Mango", one}, 2 => {"Armada", three}}), now: @now)

    assert Enum.map(rankings, & &1["player_id"]) == [2]
  end

  test "missing completed dates skip the set without crashing" do
    no_date =
      Fixtures.set(1, 1, 1, 2, %{
        "completedAt" => nil,
        "slots" => [Fixtures.slot(1, "A", 10, 1), Fixtures.slot(2, "B", 20, 2)]
      })

    dated = set(2, 1, @now - 86_400, 1, 2)

    sets =
      [no_date, dated, set(3, 1, @now - 43_200, 1, 2), set(4, 2, @now - 10_000, 1, 2)]
      |> give_events()

    rankings = Engine.compute(players(%{1 => {"Mango", sets}, 2 => {"Armada", sets}}), now: @now)
    by_id = Map.new(rankings, &{&1["player_id"], &1})
    # The undated set contributes nothing (no weight), so ratings only move on dated sets.
    assert by_id[1]["matches"] == 3
  end

  test "older results are decayed by the time weight" do
    fresh = set(1, 1, @now - 100, 1, 2)
    ancient = set(2, 2, @now - 24 * 2_592_000, 1, 2)
    fresh2 = set(3, 1, @now - 50, 1, 2)

    sets = [fresh, ancient, fresh2] |> give_events()

    # Half-life of 1 month: the ancient set (24 months old) has weight
    # 0.5^24 ≈ 6e-8, so its result barely moves ratings.
    rankings =
      Engine.compute(players(%{1 => {"Mango", sets}, 2 => {"Armada", sets}}),
        now: @now,
        half_life_months: 1
      )

    by_id = Map.new(rankings, &{&1["player_id"], &1})
    assert by_id[1]["rating"] > 1500
  end

  defp give_events(sets) do
    Enum.with_index(sets, 1)
    |> Enum.map(fn {set, i} ->
      Map.put(set, "event", %{"id" => 100 + rem(i, 3), "name" => "Event #{rem(i, 3)}"})
    end)
  end
end
