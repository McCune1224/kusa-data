defmodule KusaData.Rankings.Engine do
  @moduledoc """
  Deterministic Elo-style rating engine.

  Players start at `1500`; completed sets are processed in chronological
  order, and each match contributes `K * weight * (score - expected)`.
  The time weight decays old results (`0.5 ^ (months_old / half_life)`)
  rather than mutating stored ratings, so a season ranking can be rebuilt
  from the same set history with different windows. Players below
  `min_tournaments` completed tournaments are excluded from the ranking.

  Input shape:

      %{
        player_id => %{
          "gamer_tag" => "Mango",
          "sets" => [raw start.gg set node, ...]
        }
      }
  """

  @starting_rating 1500
  @default_k 32
  @default_min_tournaments 3
  @default_half_life_months 12

  @spec compute(map(), keyword()) :: [map()]
  def compute(players_sets, opts \\ []) do
    k = Keyword.get(opts, :k, @default_k)
    min_tournaments = Keyword.get(opts, :min_tournaments, @default_min_tournaments)
    half_life = Keyword.get(opts, :half_life_months, @default_half_life_months)
    now = Keyword.get(opts, :now, System.os_time(:second))

    prepared =
      players_sets
      |> Enum.map(fn {player_id, data} ->
        {player_id, prepare_player(player_id, data, min_tournaments, now, half_life)}
      end)
      |> Map.new()

    eligible_ids = MapSet.new(for {id, %{eligible?: true}} <- prepared, do: id)

    ordered_sets =
      prepared
      |> Map.values()
      |> Enum.flat_map(& &1.sets)
      |> Enum.uniq_by(& &1["id"])
      |> Enum.filter(&both_eligible?(&1, eligible_ids))
      |> Enum.sort_by(&(&1["completedAt"] || 0))

    ratings = Map.new(eligible_ids, &{&1, @starting_rating})
    matches = Map.new(eligible_ids, &{&1, 0})
    wins = Map.new(eligible_ids, &{&1, 0})

    {ratings, matches, wins} =
      Enum.reduce(ordered_sets, {ratings, matches, wins}, fn set, acc ->
        apply_set(acc, set, eligible_ids, k, now, half_life)
      end)

    eligible_ids
    |> Enum.map(fn player_id ->
      %{
        "player_id" => player_id,
        "gamer_tag" => prepared[player_id].gamer_tag,
        "rating" => round(ratings[player_id]),
        "matches" => matches[player_id],
        "wins" => wins[player_id],
        "losses" => matches[player_id] - wins[player_id],
        "tournaments" => prepared[player_id].tournament_count,
        "last_played" => prepared[player_id].last_played
      }
    end)
    |> Enum.sort_by(fn p -> {-p["rating"], -p["matches"], p["player_id"]} end)
  end

  defp prepare_player(player_id, data, min_tournaments, _now, _half_life) do
    sets = data["sets"] || []
    completed = Enum.filter(sets, &completed?/1)
    tournaments = completed |> Enum.map(& &1["event"]["id"]) |> Enum.uniq() |> length()
    last_played = completed |> Enum.map(& &1["completedAt"]) |> Enum.max(fn -> nil end)

    %{
      gamer_tag: data["gamer_tag"] || "Player #{player_id}",
      sets: completed,
      tournament_count: tournaments,
      last_played: last_played,
      eligible?: tournaments >= min_tournaments
    }
  end

  defp completed?(set), do: set["completedAt"] != nil and set["winnerId"] != nil

  defp both_eligible?(set, eligible_ids) do
    Enum.all?(set["slots"] || [], fn slot ->
      Enum.any?(slot["entrant"]["participants"] || [], fn p ->
        case p["user"] do
          %{"player" => %{"id" => id}} -> MapSet.member?(eligible_ids, id)
          _ -> false
        end
      end)
    end)
  end

  defp apply_set({ratings, matches, wins}, set, eligible_ids, k, now, half_life) do
    with {:ok, {player_a, player_b}} <- two_players(set, eligible_ids),
         {:ok, weight} <- time_weight(set["completedAt"], now, half_life) do
      rating_a = ratings[player_a]
      rating_b = ratings[player_b]
      expected_a = expected(rating_a, rating_b)

      score_a = if set["winnerId"] == winner_entrant_for(set, player_a), do: 1.0, else: 0.0
      score_b = 1.0 - score_a

      new_a = rating_a + k * weight * (score_a - expected_a)
      new_b = rating_b + k * weight * (score_b - (1.0 - expected_a))

      {
        %{ratings | player_a => new_a, player_b => new_b},
        %{matches | player_a => matches[player_a] + 1, player_b => matches[player_b] + 1},
        %{
          wins
          | player_a => wins[player_a] + round(score_a),
            player_b => wins[player_b] + round(score_b)
        }
      }
    else
      _ -> {ratings, matches, wins}
    end
  end

  # Identifies the two eligible players in the set's slots (by player id).
  defp two_players(set, eligible_ids) do
    players =
      (set["slots"] || [])
      |> Enum.flat_map(fn slot ->
        Enum.flat_map(slot["entrant"]["participants"] || [], fn p ->
          case p["user"] do
            %{"player" => %{"id" => id}} ->
              if MapSet.member?(eligible_ids, id), do: [id], else: []

            _ ->
              []
          end
        end)
      end)
      |> Enum.uniq()

    case players do
      [a, b] -> {:ok, {a, b}}
      _ -> :error
    end
  end

  defp winner_entrant_for(set, player_id) do
    Enum.find_value(set["slots"] || [], fn slot ->
      if slot["entrant"]["id"] == set["winnerId"] and
           Enum.any?(slot["entrant"]["participants"] || [], fn p ->
             match?(%{"player" => %{"id" => ^player_id}}, p["user"])
           end) do
        set["winnerId"]
      end
    end)
  end

  defp expected(rating_a, rating_b) do
    1.0 / (1.0 + :math.pow(10, (rating_b - rating_a) / 400.0))
  end

  # Decay weight: 0.5 ^ (months_old / half_life). Missing dates yield no
  # weight so a set can never be double-counted by recency.
  defp time_weight(completed_at, now, half_life) when is_integer(completed_at) do
    months_old = max((now - completed_at) / 2_592_000.0, 0.0)
    {:ok, :math.pow(0.5, months_old / half_life)}
  end

  defp time_weight(_completed_at, _now, _half_life), do: :error
end
