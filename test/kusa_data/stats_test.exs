defmodule KusaData.StatsTest do
  use ExUnit.Case, async: true

  alias KusaData.{Set, Stats}

  # Pure functions over in-memory Set structs — no DB.

  defp set(winner, loser, completed_at, state \\ 3) do
    %Set{
      state: state,
      winner_player_id: winner,
      loser_player_id: loser,
      completed_at: completed_at
    }
  end

  defp played(winner, loser, completed_at), do: set(winner, loser, completed_at)

  describe "win_loss/2" do
    test "counts completed scored sets for the player only" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        played(1, 3, ~U[2026-01-02 00:00:00Z]),
        played(2, 1, ~U[2026-01-03 00:00:00Z]),
        played(2, 3, ~U[2026-01-04 00:00:00Z])
      ]

      assert Stats.win_loss(sets, 1) == %{wins: 2, losses: 1, byes: 0, total: 3, win_rate: 2 / 3}
      assert Stats.win_loss(sets, 2) == %{wins: 2, losses: 1, byes: 0, total: 3, win_rate: 2 / 3}
    end

    test "ignores byes and counts them separately" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        set(1, nil, ~U[2026-01-02 00:00:00Z])
      ]

      assert Stats.win_loss(sets, 1) == %{wins: 1, losses: 0, byes: 1, total: 1, win_rate: 1.0}
    end

    test "ignores non-completed sets" do
      sets = [
        set(1, 2, ~U[2026-01-01 00:00:00Z], 2),
        set(1, 2, ~U[2026-01-02 00:00:00Z], 1),
        played(1, 2, ~U[2026-01-03 00:00:00Z])
      ]

      assert Stats.win_loss(sets, 1) == %{wins: 1, losses: 0, byes: 0, total: 1, win_rate: 1.0}
    end

    test "returns zeroed stats with nil win_rate when the player has no scored sets" do
      assert Stats.win_loss([], 1) == %{wins: 0, losses: 0, byes: 0, total: 0, win_rate: nil}
      assert Stats.win_loss([played(2, 3, ~U[2026-01-01 00:00:00Z])], 1).total == 0
    end
  end

  describe "current_streak/2" do
    test "counts the most recent consecutive wins" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        played(2, 1, ~U[2026-01-02 00:00:00Z]),
        played(1, 2, ~U[2026-01-03 00:00:00Z]),
        played(1, 2, ~U[2026-01-04 00:00:00Z])
      ]

      assert Stats.current_streak(sets, 1) == %{type: :win, count: 2}
    end

    test "counts a current losing streak" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        played(2, 1, ~U[2026-01-02 00:00:00Z]),
        played(2, 1, ~U[2026-01-03 00:00:00Z])
      ]

      assert Stats.current_streak(sets, 1) == %{type: :loss, count: 2}
    end

    test "sorts sets chronologically regardless of input order" do
      sets = [
        played(1, 2, ~U[2026-01-04 00:00:00Z]),
        played(2, 1, ~U[2026-01-01 00:00:00Z]),
        played(1, 2, ~U[2026-01-03 00:00:00Z])
      ]

      assert Stats.current_streak(sets, 1) == %{type: :win, count: 2}
    end

    test "byes do not break a streak" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        set(1, nil, ~U[2026-01-02 00:00:00Z]),
        played(1, 3, ~U[2026-01-03 00:00:00Z])
      ]

      assert Stats.current_streak(sets, 1) == %{type: :win, count: 2}
    end

    test "returns nil type when the player has no results" do
      assert Stats.current_streak([], 1) == %{type: nil, count: 0}
    end
  end

  describe "best_streak/2" do
    test "tracks the longest win and loss streaks separately" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        played(1, 3, ~U[2026-01-02 00:00:00Z]),
        played(1, 4, ~U[2026-01-03 00:00:00Z]),
        played(2, 1, ~U[2026-01-04 00:00:00Z]),
        played(3, 1, ~U[2026-01-05 00:00:00Z]),
        played(4, 1, ~U[2026-01-06 00:00:00Z]),
        played(5, 1, ~U[2026-01-07 00:00:00Z]),
        played(1, 2, ~U[2026-01-08 00:00:00Z])
      ]

      assert Stats.best_streak(sets, 1) == %{win: 3, loss: 4}
    end

    test "returns zeroed streaks without results" do
      assert Stats.best_streak([], 1) == %{win: 0, loss: 0}
    end
  end

  describe "h2h/2" do
    test "counts only direct completed sets between the two players" do
      sets = [
        played(1, 2, ~U[2026-01-01 00:00:00Z]),
        played(1, 2, ~U[2026-01-02 00:00:00Z]),
        played(2, 1, ~U[2026-01-03 00:00:00Z]),
        played(1, 3, ~U[2026-01-04 00:00:00Z]),
        played(2, 3, ~U[2026-01-05 00:00:00Z]),
        set(2, 1, ~U[2026-01-06 00:00:00Z], 2)
      ]

      assert Stats.h2h(sets, 1, 2) == %{wins_a: 2, wins_b: 1, total: 3}
      assert Stats.h2h(sets, 2, 1) == %{wins_a: 1, wins_b: 2, total: 3}
    end

    test "returns zeroed record without mutual sets" do
      assert Stats.h2h([], 1, 2) == %{wins_a: 0, wins_b: 0, total: 0}
      assert Stats.h2h([played(3, 4, ~U[2026-01-01 00:00:00Z])], 1, 2).total == 0
    end
  end
end
