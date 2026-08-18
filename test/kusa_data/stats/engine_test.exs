defmodule KusaData.Stats.EngineTest do
  use ExUnit.Case, async: true

  alias KusaData.Stats.Engine
  alias KusaData.Test.Fixtures

  @identity %{"player_id" => 100, "gamer_tag" => "Mango", "user_id" => 10}
  @our_entrant 1
  @them_entrant 2

  test "scores completed sets into a record" do
    sets = [
      Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant),
      Fixtures.set(2, @our_entrant, @them_entrant, @them_entrant),
      Fixtures.set(3, @our_entrant, @them_entrant, @our_entrant)
    ]

    stats = Engine.build(@identity, sets)

    assert stats["wins"] == 2
    assert stats["losses"] == 1
    assert stats["completed_sets"] == 3
    assert stats["win_rate"] == 66.7
  end

  test "ignores unfinished sets" do
    finished = Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant)
    pending = Fixtures.set(2, @our_entrant, @them_entrant, nil, %{"completedAt" => nil})
    running = Fixtures.set(3, @our_entrant, @them_entrant, nil, %{"state" => 2})

    stats = Engine.build(@identity, [finished, pending, running])

    assert stats["sets_seen"] == 3
    assert stats["completed_sets"] == 1
    assert stats["wins"] == 1
  end

  test "aggregates character usage only for our side" do
    set = Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant)

    stats = Engine.build(@identity, [set])

    assert stats["characters"] == [%{"name" => "Luigi", "games" => 1, "wins" => 1}]
  end

  test "aggregates head-to-head records" do
    sets = [
      Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant),
      Fixtures.set(2, @our_entrant, @them_entrant, @them_entrant)
    ]

    stats = Engine.build(@identity, sets)

    assert stats["opponents"] == [
             %{
               "name" => "Armada",
               "opponent_player_id" => 200,
               "unresolved" => false,
               "wins" => 1,
               "losses" => 1,
               "total" => 2
             }
           ]
  end

  test "recent sets are sorted newest first with per-game scores" do
    sets = [
      Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant),
      Fixtures.set(2, @our_entrant, @them_entrant, @them_entrant)
    ]

    stats = Engine.build(@identity, sets)

    assert [newest, oldest] = stats["recent_sets"]
    assert newest["id"] == 2
    assert newest["won"] == false
    assert newest["score_us"] == 0
    assert newest["score_them"] == 1
    assert newest["opponent"] == "Armada"
    assert newest["event"] == "Melee Singles"
    assert newest["round"] == "Winners Round 1"
    assert oldest["won"] == true
  end

  test "empty history produces a zeroed profile" do
    stats = Engine.build(@identity, [])

    assert stats["wins"] == 0
    assert stats["losses"] == 0
    assert stats["win_rate"] == 0.0
    assert stats["characters"] == []
    assert stats["opponents"] == []
    assert stats["recent_sets"] == []
  end

  test "counts completed sets even when per-game data is missing" do
    # start.gg sometimes returns sets with a set-level winnerId + completedAt
    # but a null `games` breakdown; those must still count toward the record.
    set_without_games =
      Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant)
      |> Map.put("games", nil)

    stats = Engine.build(@identity, [set_without_games])

    assert stats["completed_sets"] == 1
    assert stats["wins"] == 1
    assert stats["characters"] == []
  end

  test "retains opponent player ids and marks name-only rows unresolved" do
    named = Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant)
    # Opponent slot without a player id (user only).
    no_id =
      Fixtures.set(2, @our_entrant, @them_entrant, @them_entrant)
      |> Map.put("slots", [
        Fixtures.slot(@our_entrant, "Mango", 10, 100),
        Fixtures.slot(@them_entrant, "Mystery", 21)
      ])

    stats = Engine.build(@identity, [named, no_id])

    by_name = Map.new(stats["opponents"], &{&1["name"], &1})

    assert by_name["Armada"]["opponent_player_id"] == 200
    assert by_name["Armada"]["unresolved"] == false
    assert by_name["Mystery"]["opponent_player_id"] == nil
    assert by_name["Mystery"]["unresolved"] == true

    recent = Map.new(stats["recent_sets"], &{&1["id"], &1})
    assert recent[1]["opponent_player_id"] == 200
    assert recent[1]["opponent_unresolved"] == false
    assert recent[2]["opponent_unresolved"] == true
  end

  test "builds a character matchup grid from both sides' selections" do
    set = Fixtures.set(1, @our_entrant, @them_entrant, @our_entrant)

    stats = Engine.build(@identity, [set])

    # Luigi (ours) vs Marth (theirs): 1 game, 1 win.
    assert stats["matchups"] == [
             %{
               "character" => "Luigi",
               "opponent_character" => "Marth",
               "games" => 1,
               "wins" => 1
             }
           ]

    assert stats["matchup_grid"]["columns"] == ["Marth"]
    assert [row] = stats["matchup_grid"]["rows"]
    assert row["character"] == "Luigi"
    assert [cell] = row["cells"]
    assert cell["games"] == 1
    assert cell["wins"] == 1
  end

  test "matchup grid leaves missing pairs as insufficient-data cells" do
    stats = Engine.build(@identity, [])

    assert stats["matchup_grid"] == %{"columns" => [], "rows" => []}
    assert stats["matchups"] == []
  end
end
