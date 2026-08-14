defmodule KusaData.Stats do
  @moduledoc """
  Player stat computations over crawled `KusaData.Set` structs. Pure — no I/O —
  so every branch is unit-testable. All functions take the full set list plus
  the player (or players) they describe.

  Conventions:
    * only completed sets (state 3) count;
    * byes (winner present, loser nil) are excluded from W/L and streaks but
      tracked separately in `win_loss/2`;
    * streaks and H2H sort sets chronologically by `completed_at`, so input
      order never matters.
  """

  alias KusaData.Set

  # A set with no completed_at sorts before everything real (Melee era > 1970).
  @sort_epoch ~U[1970-01-01 00:00:00Z]

  @type win_loss :: %{
          wins: non_neg_integer,
          losses: non_neg_integer,
          byes: non_neg_integer,
          total: non_neg_integer,
          win_rate: float | nil
        }
  @type streak :: %{type: :win | :loss | nil, count: non_neg_integer}
  @type h2h :: %{wins_a: non_neg_integer, wins_b: non_neg_integer, total: non_neg_integer}

  @doc """
  Win/loss record for `player_id` across `sets`. `win_rate` is the fraction of
  scored sets won (0.0..1.0), or `nil` when the player has no scored sets.
  """
  @spec win_loss([Set.t()], integer) :: win_loss
  def win_loss(sets, player_id) do
    {wins, losses, byes} =
      Enum.reduce(sets, {0, 0, 0}, fn set, {w, l, b} ->
        case result_for(set, player_id) do
          :win -> {w + 1, l, b}
          :loss -> {w, l + 1, b}
          :bye -> {w, l, b + 1}
          nil -> {w, l, b}
        end
      end)

    total = wins + losses

    %{
      wins: wins,
      losses: losses,
      byes: byes,
      total: total,
      win_rate: if(total == 0, do: nil, else: wins / total)
    }
  end

  @doc """
  The player's current streak: `{type, count}` of consecutive wins or losses
  ending with their most recent completed set. `%{type: nil, count: 0}` when
  they have no scored sets.
  """
  @spec current_streak([Set.t()], integer) :: streak
  def current_streak(sets, player_id) do
    case results_for(sets, player_id) do
      [] ->
        %{type: nil, count: 0}

      results ->
        type = List.last(results)

        %{
          type: type,
          count: results |> Enum.reverse() |> Enum.take_while(&(&1 == type)) |> length()
        }
    end
  end

  @doc """
  The player's longest win and loss streaks across all completed sets.
  """
  @spec best_streak([Set.t()], integer) :: %{win: non_neg_integer, loss: non_neg_integer}
  def best_streak(sets, player_id) do
    results = results_for(sets, player_id)

    %{
      win: longest_run(results, :win),
      loss: longest_run(results, :loss)
    }
  end

  @doc """
  Head-to-head record between two players: `wins_a` is how many of their
  mutual sets `player_a_id` won. Only direct, completed, scored sets count.
  """
  @spec h2h([Set.t()], integer, integer) :: h2h
  def h2h(sets, player_a_id, player_b_id) do
    wins_a =
      Enum.count(sets, fn set ->
        set.state == 3 and set.winner_player_id == player_a_id and
          set.loser_player_id == player_b_id
      end)

    wins_b =
      Enum.count(sets, fn set ->
        set.state == 3 and set.winner_player_id == player_b_id and
          set.loser_player_id == player_a_id
      end)

    %{wins_a: wins_a, wins_b: wins_b, total: wins_a + wins_b}
  end

  # The player's per-set result in chronological order: [:win | :loss], byes
  # dropped, non-involvement and non-completed sets dropped.
  defp results_for(sets, player_id) do
    sets
    |> Enum.sort_by(&timestamp/1)
    |> Enum.flat_map(fn set ->
      case result_for(set, player_id) do
        r when r in [:win, :loss] -> [r]
        _ -> []
      end
    end)
  end

  defp result_for(set, player_id) do
    cond do
      set.state != 3 -> nil
      set.winner_player_id == player_id and is_nil(set.loser_player_id) -> :bye
      set.winner_player_id == player_id -> :win
      set.loser_player_id == player_id -> :loss
      true -> nil
    end
  end

  defp timestamp(%{completed_at: nil}), do: DateTime.to_unix(@sort_epoch, :second)
  defp timestamp(%{completed_at: completed_at}), do: DateTime.to_unix(completed_at, :second)

  defp longest_run(results, type) do
    results
    |> Enum.chunk_by(& &1)
    |> Enum.filter(fn [head | _] -> head == type end)
    |> Enum.map(&length/1)
    |> Enum.max(fn -> 0 end)
  end
end
