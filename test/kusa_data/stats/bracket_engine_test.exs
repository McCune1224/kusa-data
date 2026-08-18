defmodule KusaData.Stats.BracketEngineTest do
  use ExUnit.Case, async: true

  alias KusaData.Stats.BracketEngine
  alias KusaData.Test.Fixtures

  defp seeds(pairs) do
    Enum.map(pairs, fn {id, seed} ->
      %{"id" => id, "name" => "Player #{id}", "seed" => seed, "player_id" => id * 100}
    end)
  end

  defp standings(pairs) do
    Enum.map(pairs, fn {id, placement} ->
      %{
        "entrant_id" => id,
        "name" => "Player #{id}",
        "placement" => placement,
        "player_id" => id * 100
      }
    end)
  end

  test "computes seed deltas and flags upsets for the fixture scenario" do
    # seeds {1, 4} → placements {2, 1}: seed 4 won the event (+3), seed 1 was close.
    analysis =
      BracketEngine.analyze(
        seeds([{1, 1}, {4, 4}]),
        standings([{1, 2}, {4, 1}]),
        [Fixtures.mapped_set(1, 4, [1, 4])],
        %{"event_id" => 100, "event_name" => "Melee Singles", "start_at" => 1_784_000_000}
      )

    by_id = Map.new(analysis["entrants"], &{&1["entrant_id"], &1})

    assert by_id[4]["seed_delta"] == 3
    assert by_id[4]["upset"] == true
    assert by_id[4]["reason"] == "reseeded"
    assert by_id[1]["seed_delta"] == -1
    assert by_id[1]["upset"] == false
    assert length(analysis["upsets"]) == 1
    assert hd(analysis["upsets"])["entrant_id"] == 4
  end

  test "joins W/L strictly by entrant id, never by display name" do
    # Same display name for two different entrants; sets belong to ids 1 and 2.
    sets = [
      Fixtures.mapped_set(1, 1, [1, 2]),
      Fixtures.mapped_set(2, 2, [1, 2]),
      Fixtures.mapped_set(3, 1, [1, 2])
    ]

    entrants = [
      %{"id" => 1, "name" => "Mango", "seed" => 1, "player_id" => nil},
      %{"id" => 2, "name" => "Mango", "seed" => 2, "player_id" => nil}
    ]

    analysis = BracketEngine.analyze(entrants, [], sets)
    by_id = Map.new(analysis["entrants"], &{&1["entrant_id"], &1})

    assert by_id[1]["wins"] == 2
    assert by_id[1]["losses"] == 1
    assert by_id[2]["wins"] == 1
    assert by_id[2]["losses"] == 2
    assert by_id[1]["games_won"] == 6
    assert by_id[1]["games_lost"] == 1
    assert by_id[2]["games_won"] == 3
  end

  test "handles missing seeds and placements without guessing" do
    # Unseeded entrant that made top 8; seeded entrant with no placement.
    analysis =
      BracketEngine.analyze(
        seeds([{1, nil}, {2, 2}]),
        standings([{1, 4}]),
        [],
        %{"event_id" => 100}
      )

    by_id = Map.new(analysis["entrants"], &{&1["entrant_id"], &1})

    assert by_id[1]["seed"] == nil
    assert by_id[1]["placement"] == 4
    assert by_id[1]["seed_delta"] == nil
    assert by_id[1]["upset"] == false
    assert by_id[1]["reason"] == "unseeded_top_finish"
    assert by_id[2]["placement"] == nil
    assert by_id[2]["reason"] == nil
    assert Enum.any?(analysis["anomalies"], &(&1["entrant_id"] == 1))
  end

  test "flags changed seeds for top seeds that finish far below seed" do
    analysis = BracketEngine.analyze(seeds([{1, 1}, {2, 2}]), standings([{1, 17}, {2, 1}]), [])
    by_id = Map.new(analysis["entrants"], &{&1["entrant_id"], &1})
    assert by_id[1]["reason"] == "changed_seed"
    assert by_id[2]["reason"] == nil
  end

  test "placement ties keep entrants separate and don't crash" do
    analysis = BracketEngine.analyze(seeds([{1, 1}, {2, 2}]), standings([{1, 5}, {2, 5}]), [])
    assert length(analysis["entrants"]) == 2
    assert Enum.all?(analysis["entrants"], &(&1["placement"] == 5))
  end

  test "zero-match events report zero match count and nil average" do
    analysis = BracketEngine.analyze(seeds([{1, 1}]), standings([{1, 1}]), [])
    assert analysis["match_count"] == 0
    assert analysis["avg_sets_per_entrant"] == 0.0
  end

  test "DQ rate is nil unless the API supplies an explicit DQ field" do
    no_dq = BracketEngine.analyze([], [%{"entrant_id" => 1, "placement" => 1}], [])
    assert no_dq["dq_rate"] == nil

    with_dq =
      BracketEngine.analyze(
        [],
        [
          %{"entrant_id" => 1, "placement" => 1},
          %{"entrant_id" => 2, "placement" => 2, "isDisqualified" => true}
        ],
        []
      )

    assert with_dq["dq_count"] == 1
    assert with_dq["dq_rate"] == 50.0
  end

  test "large entrant lists produce complete W/L tables" do
    entrants = seeds(Enum.map(1..500, &{&1, &1}))
    # 1000 sets, one per pair
    sets =
      Enum.map(1..500, fn i ->
        Fixtures.mapped_set(i, i, [i, rem(i, 500) + 1])
      end)

    analysis = BracketEngine.analyze(entrants, [], sets)
    assert length(analysis["entrants"]) == 500
    assert analysis["match_count"] == 500
    total_sets = Enum.reduce(analysis["entrants"], 0, fn e, acc -> acc + e["sets_played"] end)
    assert total_sets == 1000
  end

  test "upset_of_weekend ranks swings within a date window" do
    context = %{"start_at" => 1_784_000_000, "event_name" => "Major", "tournament_name" => "Big"}

    analyses = [
      BracketEngine.analyze(seeds([{1, 16}]), standings([{1, 2}]), [], context),
      BracketEngine.analyze(seeds([{2, 8}]), standings([{2, 3}]), [], context)
    ]

    ranked = BracketEngine.upset_of_weekend(analyses, 1_783_000_000, 1_785_000_000)
    assert Enum.map(ranked, & &1["entrant_id"]) == [1, 2]
    assert hd(ranked)["seed_delta"] == 14

    # Outside the window → excluded.
    assert BracketEngine.upset_of_weekend(analyses, 1_790_000_000, 1_795_000_000) == []
  end

  test "recap renders unavailable DQ and counts" do
    analysis = BracketEngine.analyze(seeds([{1, 1}]), standings([{1, 1}]), [])
    recap = BracketEngine.recap(analysis)
    assert recap["entrant_count"] == 1
    assert recap["dq_rate"] == nil
    assert recap["upset_count"] == 0
  end
end
