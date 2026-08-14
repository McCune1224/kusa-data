defmodule KusaData.EloTest do
  use ExUnit.Case, async: true

  alias KusaData.Elo

  defp slot(user_id, score) do
    %{
      entrant: %{participants: [%{user: %{id: user_id}}]},
      standing: %{stats: %{score: %{value: score}}}
    }
  end

  defp set(state, slots) do
    %{state: state, completed_at: 1_700_000_000, slots: slots}
  end

  describe "expected_score/2" do
    test "equal ratings split the point" do
      assert Elo.expected_score(1500, 1500) == 0.5
    end

    test "higher-rated player is favored" do
      assert Elo.expected_score(1700, 1200) > 0.9
      assert Elo.expected_score(1200, 1700) < 0.1
    end

    test "is symmetric" do
      assert Elo.expected_score(1400, 1600) + Elo.expected_score(1600, 1400) == 1.0
    end
  end

  describe "apply_set/2" do
    test "equal ratings: win moves +16, loss moves -16" do
      ratings = %{}
      assert {:ok, ratings} = Elo.apply_set(ratings, set(3, [slot(1, 3), slot(2, 0)]))
      assert_in_delta ratings[1].elo, 1516, 0.01
      assert_in_delta ratings[2].elo, 1484, 0.01
      assert ratings[1].sets == 1 and ratings[1].wins == 1 and ratings[1].losses == 0
      assert ratings[2].sets == 1 and ratings[2].wins == 0 and ratings[2].losses == 1
    end

    test "upset: 1200 beats 1700 gains ~30" do
      ratings = %{
        3 => %{elo: 1200, sets: 0, wins: 0, losses: 0},
        4 => %{elo: 1700, sets: 0, wins: 0, losses: 0}
      }

      assert {:ok, ratings} = Elo.apply_set(ratings, set(3, [slot(3, 2), slot(4, 1)]))
      assert_in_delta ratings[3].elo, 1230, 1
      assert_in_delta ratings[4].elo, 1670, 1
    end

    test "tie updates both by half a K step" do
      ratings = %{
        5 => %{elo: 1500, sets: 0, wins: 0, losses: 0},
        6 => %{elo: 1500, sets: 0, wins: 0, losses: 0}
      }

      assert {:ok, ratings} = Elo.apply_set(ratings, set(3, [slot(5, 2), slot(6, 2)]))
      assert_in_delta ratings[5].elo, 1500, 0.01
      assert_in_delta ratings[6].elo, 1500, 0.01
      assert ratings[5].wins == 0 and ratings[5].losses == 0
    end

    test "non-complete sets are ignored" do
      ratings = %{
        7 => %{elo: 1500, sets: 0, wins: 0, losses: 0},
        8 => %{elo: 1500, sets: 0, wins: 0, losses: 0}
      }

      assert :ignore = Elo.apply_set(ratings, set(2, [slot(7, 3), slot(8, 0)]))
    end

    test "byes and missing scores are ignored" do
      ratings = %{9 => %{elo: 1500, sets: 0, wins: 0, losses: 0}}
      assert :ignore = Elo.apply_set(ratings, set(3, [slot(9, 3)]))
      assert :ignore = Elo.apply_set(ratings, set(3, [slot(9, nil), slot(10, nil)]))
    end

    test "unknown players start at 1500" do
      assert {:ok, ratings} = Elo.apply_set(%{}, set(3, [slot(11, 1), slot(12, 0)]))
      assert ratings[11].elo == 1516
      assert ratings[12].elo == 1484
    end
  end
end
