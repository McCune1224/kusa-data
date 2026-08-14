defmodule KusaData.Elo do
  @moduledoc """
  Opponent-aware Elo engine (K=32, seed 1500), ported from the previous
  TypeScript implementation. Pure — no I/O — so every branch is unit-testable.

  Ratings are keyed by start.gg user id:
      %{user_id => %{elo: float, sets: non_neg_integer, wins: non_neg_integer, losses: non_neg_integer}}
  """

  @initial_elo 1500.0
  @k 32.0

  @type rating :: %{
          elo: float,
          sets: non_neg_integer,
          wins: non_neg_integer,
          losses: non_neg_integer
        }
  @type ratings :: %{optional(integer) => rating}

  @doc "Expected score (0..1) for a player rated `a` against `b`."
  @spec expected_score(number, number) :: float
  def expected_score(a, b) do
    1 / (1 + :math.pow(10, (b - a) / 400))
  end

  @doc """
  Applies one completed set to the ratings map.

  Returns `{:ok, ratings}` when the set was scored, `:ignore` otherwise
  (non-complete set, bye, or missing user/score data). The input map is
  never mutated.
  """
  @spec apply_set(ratings, map) :: {:ok, ratings} | :ignore
  def apply_set(ratings, set) do
    with %{state: 3} <- set,
         {user_a, score_a, user_b, score_b} <- scored_slots(set) do
      ra = Map.get(ratings, user_a, blank())
      rb = Map.get(ratings, user_b, blank())

      actual_a =
        cond do
          score_a > score_b -> 1.0
          score_b > score_a -> 0.0
          true -> 0.5
        end

      expected_a = expected_score(ra.elo, rb.elo)

      ratings =
        ratings
        |> Map.put(user_a, update(ra, actual_a, expected_a))
        |> Map.put(user_b, update(rb, 1 - actual_a, 1 - expected_a))

      {:ok, ratings}
    else
      _ -> :ignore
    end
  end

  defp blank, do: %{elo: @initial_elo, sets: 0, wins: 0, losses: 0}

  defp update(rating, actual, expected) do
    %{
      elo: Float.round(rating.elo + @k * (actual - expected)),
      sets: rating.sets + 1,
      wins: rating.wins + if(actual == 1.0, do: 1, else: 0),
      losses: rating.losses + if(actual == 0.0, do: 1, else: 0)
    }
  end

  # Extracts the two scored slots as {user_a, score_a, user_b, score_b}.
  defp scored_slots(%{slots: slots}) do
    scored =
      Enum.flat_map(slots, fn slot ->
        with %{value: score} when not is_nil(score) <- get_in(slot, [:standing, :stats, :score]),
             %{id: user_id} <- get_in(slot, [:entrant, :participants, Access.at(0), :user]) do
          [{user_id, score}]
        else
          _ -> []
        end
      end)

    case scored do
      [{user_a, score_a}, {user_b, score_b}] -> {user_a, score_a, user_b, score_b}
      _ -> :error
    end
  end
end
