defmodule KusaData.Stats.BracketEngine do
  @moduledoc """
  Pure bracket analytics: seeds versus final placement, entrant W/L from
  sets, and per-event recap metrics.

  Every join is by entrant id — display names are never used as keys, so tag
  changes or duplicate names cannot corrupt the analysis. DQ status is only
  reported when the API supplies an explicit DQ field; otherwise `dq_rate` is
  `nil` and callers render "unavailable" instead of an invented rate.

  Input shapes (as produced by `KusaData.Events`):

    * seeds:     `%{"id", "name", "seed", "player_id"}`
    * standings: `%{"placement", "entrant_id", "name", "player_id"}`
    * sets:      `%{"id", "winner_id", "display_score", "slots", "completed_at", ...}`
  """

  @top_finish_threshold 8

  @doc """
  Full analysis for one event. `context` carries display metadata
  (`event_id`, `event_name`, `tournament_slug`, `tournament_name`,
  `start_at`) that the recap and upset ranking propagate.
  """
  @spec analyze([map()], [map()], [map()], map()) :: map()
  def analyze(seeds, standings, sets, context \\ %{}) do
    seed_by_entrant = Map.new(seeds, &{&1["id"], &1["seed"]})
    placement_by_entrant = Map.new(standings, &{&1["entrant_id"], &1["placement"]})

    name_by_entrant =
      Map.new(seeds, &{&1["id"], &1["name"]})
      |> Map.merge(Map.new(standings, &{&1["entrant_id"], &1["name"]}))

    player_by_entrant =
      Map.new(seeds, &{&1["id"], &1["player_id"]})
      |> Map.merge(Map.new(standings, &{&1["entrant_id"], &1["player_id"]}))

    entrant_ids =
      Map.keys(seed_by_entrant)
      |> Kernel.++(Map.keys(placement_by_entrant))
      |> Kernel.++(set_entrant_ids(sets))
      |> Enum.uniq()

    set_stats = set_stats_by_entrant(sets)

    entrants =
      Enum.map(entrant_ids, fn entrant_id ->
        seed = seed_by_entrant[entrant_id]
        placement = placement_by_entrant[entrant_id]
        stats = Map.get(set_stats, entrant_id, empty_stats())
        delta = delta(seed, placement)

        %{
          "entrant_id" => entrant_id,
          "name" => name_by_entrant[entrant_id] || "—",
          "player_id" => player_by_entrant[entrant_id],
          "seed" => seed,
          "placement" => placement,
          "seed_delta" => delta,
          "upset" => is_integer(delta) and delta >= 2,
          "reason" => anomaly_reason(seed, placement, delta),
          "wins" => stats.wins,
          "losses" => stats.losses,
          "sets_played" => stats.wins + stats.losses,
          "games_won" => stats.games_won,
          "games_lost" => stats.games_lost
        }
      end)
      |> Enum.sort_by(fn e -> {e["placement"] || 999_999, e["seed"] || 999_999} end)

    {dq_count, dq_rate} = dq_stats(standings)

    %{
      "context" => context,
      "entrants" => entrants,
      "entrant_count" => length(entrants),
      "match_count" => length(sets),
      "avg_sets_per_entrant" => avg_sets(length(entrants), length(sets)),
      "dq_count" => dq_count,
      "dq_rate" => dq_rate,
      "upsets" => upsets(entrants),
      "anomalies" => anomalies(entrants)
    }
  end

  @doc "Compact recap panel payload for an event."
  @spec recap(map()) :: map()
  def recap(analysis) do
    %{
      "event_id" => analysis["context"]["event_id"],
      "event_name" => analysis["context"]["event_name"],
      "tournament_name" => analysis["context"]["tournament_name"],
      "entrant_count" => analysis["entrant_count"],
      "match_count" => analysis["match_count"],
      "avg_sets_per_entrant" => analysis["avg_sets_per_entrant"],
      "dq_rate" => analysis["dq_rate"],
      "dq_count" => analysis["dq_count"],
      "upset_count" => length(analysis["upsets"]),
      "anomaly_count" => length(analysis["anomalies"])
    }
  end

  @doc """
  "Upset of the weekend": the largest positive seed-to-placement swings across
  analyses whose tournament started inside the `[from_unix, to_unix)` window.
  """
  @spec upset_of_weekend([map()], integer(), integer()) :: [map()]
  def upset_of_weekend(analyses, from_unix, to_unix) do
    analyses
    |> Enum.flat_map(fn analysis ->
      Enum.map(analysis["upsets"], &attach_context(&1, analysis["context"]))
    end)
    |> Enum.filter(fn upset ->
      start_at = upset["start_at"]
      is_integer(start_at) and start_at >= from_unix and start_at < to_unix
    end)
    |> Enum.sort_by(& &1["seed_delta"], :desc)
  end

  defp attach_context(upset, context) do
    Map.merge(upset, %{
      "event_id" => context["event_id"],
      "event_name" => context["event_name"],
      "tournament_slug" => context["tournament_slug"],
      "tournament_name" => context["tournament_name"],
      "start_at" => context["start_at"]
    })
  end

  defp empty_stats, do: %{wins: 0, losses: 0, games_won: 0, games_lost: 0}

  defp delta(seed, placement) when is_integer(seed) and is_integer(placement),
    do: seed - placement

  defp delta(_seed, _placement), do: nil

  defp anomaly_reason(seed, placement, delta) do
    cond do
      seed == nil and is_integer(placement) and placement <= @top_finish_threshold ->
        "unseeded_top_finish"

      is_integer(delta) and delta >= 2 ->
        "reseeded"

      is_integer(delta) and delta <= -2 ->
        "changed_seed"

      true ->
        nil
    end
  end

  defp set_entrant_ids(sets) do
    Enum.flat_map(sets, fn set ->
      Enum.map(set["slots"] || [], fn slot -> slot["entrant_id"] end)
    end)
  end

  defp set_stats_by_entrant(sets) do
    Enum.reduce(sets, %{}, fn set, acc ->
      winner_id = set["winner_id"]

      if is_integer(winner_id) do
        {winner_games, loser_games} = parse_score(set["display_score"])
        loser_id = find_loser(set["slots"], winner_id)

        acc
        |> bump(winner_id, :wins, 1)
        |> bump(winner_id, :games_won, winner_games)
        |> bump(loser_id, :losses, 1)
        |> bump(loser_id, :games_lost, loser_games)
      else
        acc
      end
    end)
  end

  defp bump(acc, nil, _key, _amount), do: acc

  defp bump(acc, entrant_id, key, amount) do
    current = Map.get(acc, entrant_id, empty_stats())
    Map.put(acc, entrant_id, Map.update!(current, key, &(&1 + amount)))
  end

  defp find_loser(slots, winner_id) do
    case Enum.find(slots, fn slot -> slot["entrant_id"] != winner_id end) do
      %{"entrant_id" => id} -> id
      _ -> nil
    end
  end

  # displayScore like "3 - 1": the winner won more games, so the larger
  # number belongs to the winner. Unparseable scores contribute zero games.
  defp parse_score(score) when is_binary(score) do
    case Regex.run(~r/(\d+)\D+(\d+)/, score) do
      [_, a, b] ->
        a = String.to_integer(a)
        b = String.to_integer(b)
        {max(a, b), min(a, b)}

      _ ->
        {0, 0}
    end
  end

  defp parse_score(_), do: {0, 0}

  defp avg_sets(0, _matches), do: nil

  defp avg_sets(entrant_count, match_count) do
    round(match_count * 200 / entrant_count) / 100
  end

  defp upsets(entrants) do
    entrants
    |> Enum.filter(& &1["upset"])
    |> Enum.sort_by(& &1["seed_delta"], :desc)
  end

  defp anomalies(entrants) do
    entrants
    |> Enum.filter(& &1["reason"])
    |> Enum.sort_by(& &1["seed_delta"], :desc)
  end

  # DQ is only reported when at least one standings row carries an explicit
  # DQ field; otherwise the pair is `{nil, nil}`.
  defp dq_stats(standings) do
    flags = Enum.map(standings, &explicit_dq/1)

    if Enum.any?(flags, &(&1 != nil)) do
      count = Enum.count(flags, &(&1 == true))
      total = length(standings)
      rate = if total == 0, do: 0.0, else: round(count * 1000 / total) / 10
      {count, rate}
    else
      {nil, nil}
    end
  end

  defp explicit_dq(standing) do
    cond do
      Map.has_key?(standing, "isDisqualified") -> standing["isDisqualified"] == true
      Map.has_key?(standing, "dq") -> standing["dq"] == true
      true -> nil
    end
  end
end
