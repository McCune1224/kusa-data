defmodule KusaData.Stats.Engine do
  @moduledoc """
  Pure set-sheet → player stats computation.

  Takes a player identity (`%{"player_id", "gamer_tag", "user_id"}`) and a
  list of raw start.gg set nodes and produces a JSON-safe stats map with
  string keys (so cached copies behave identically to fresh ones). Fully
  deterministic and unit-testable with fixture payloads.

  Opponent identity is retained as `opponent_player_id` wherever start.gg
  exposes it; rows without a player id are marked `unresolved` and keep the
  display-name fallback only.
  """

  @characters_limit 8
  @opponents_limit 6
  @recent_limit 15

  @spec build(map(), [map()]) :: map()
  def build(%{"user_id" => user_id} = identity, sets) do
    completed = Enum.filter(sets, &completed?/1)

    scored =
      completed
      |> Enum.map(&score_set(&1, user_id))
      |> Enum.filter(& &1)

    {wins, losses} =
      Enum.reduce(scored, {0, 0}, fn set, {w, l} ->
        if set["won"], do: {w + 1, l}, else: {w, l + 1}
      end)

    total = wins + losses
    win_rate = if total == 0, do: 0.0, else: round(wins * 1000 / total) / 10
    matchups = matchups(scored)

    %{
      "player_id" => identity["player_id"],
      "gamer_tag" => identity["gamer_tag"],
      "user_id" => user_id,
      "sets_seen" => length(sets),
      "completed_sets" => total,
      "wins" => wins,
      "losses" => losses,
      "win_rate" => win_rate,
      "characters" => characters(scored),
      "matchups" => matchups,
      "matchup_grid" => matchup_grid(matchups),
      "opponents" => opponents(scored),
      "recent_sets" => recent_sets(scored)
    }
  end

  defp completed?(set), do: set["completedAt"] != nil && set["winnerId"] != nil

  defp score_set(set, user_id) do
    with our_slot <- our_slot(set, user_id),
         opponent <- opponent_slot(set, our_slot),
         %{"entrant" => %{"id" => our_entrant_id}} <- our_slot do
      our_games = played_games(set)
      games_won = Enum.count(our_games, fn game -> game["winnerId"] == our_entrant_id end)
      games_lost = length(our_games) - games_won
      opponent_player_id = opponent_player_id(opponent)

      %{
        "id" => set["id"],
        "won" => set["winnerId"] == our_entrant_id,
        "score_us" => games_won,
        "score_them" => games_lost,
        "display_score" => set["displayScore"],
        "round" => set["fullRoundText"] || "Set",
        "event" => set["event"]["name"],
        "event_id" => set["event"]["id"],
        "completed_at" => set["completedAt"],
        "opponent" => opponent_name(opponent),
        "opponent_player_id" => opponent_player_id,
        "opponent_unresolved" => opponent_player_id == nil,
        "characters" => characters_for(set, our_entrant_id),
        "matchups" => matchup_pairs(set, our_entrant_id)
      }
    else
      _ -> nil
    end
  end

  defp our_slot(set, user_id) do
    Enum.find(set["slots"], fn slot ->
      slot["entrant"]["participants"]
      |> Enum.any?(fn participant -> participant["user"]["id"] == user_id end)
    end)
  end

  defp opponent_slot(set, our_slot) do
    Enum.find(set["slots"], fn slot -> slot != our_slot end)
  end

  defp opponent_name(nil), do: "—"
  defp opponent_name(slot), do: slot["entrant"]["name"]

  defp opponent_player_id(nil), do: nil

  defp opponent_player_id(slot) do
    Enum.find_value(slot["entrant"]["participants"] || [], fn participant ->
      case participant do
        %{"user" => %{"player" => %{"id" => player_id}}} -> player_id
        _ -> nil
      end
    end)
  end

  defp played_games(set),
    do: (set["games"] || []) |> Enum.filter(fn game -> game["winnerId"] != nil end)

  defp characters_for(set, our_entrant_id) do
    (set["games"] || [])
    |> Enum.flat_map(fn game ->
      (game["selections"] || [])
      |> Enum.filter(&character_selection?/1)
      |> Enum.filter(fn selection -> selection["entrant"]["id"] == our_entrant_id end)
      |> Enum.map(fn selection -> selection["character"]["name"] end)
    end)
    |> Enum.uniq()
  end

  # Per played game: our character vs their character with the result, when
  # both sides selected characters. Stored as JSON-safe maps (scored sets are
  # cached).
  defp matchup_pairs(set, our_entrant_id) do
    (set["games"] || [])
    |> Enum.flat_map(fn game ->
      selections = Enum.filter(game["selections"] || [], &character_selection?/1)

      our_char =
        Enum.find_value(selections, fn selection ->
          if selection["entrant"]["id"] == our_entrant_id, do: selection["character"]["name"]
        end)

      their_char =
        Enum.find_value(selections, fn selection ->
          if selection["entrant"]["id"] != our_entrant_id, do: selection["character"]["name"]
        end)

      if our_char && their_char do
        [
          %{
            "character" => our_char,
            "opponent_character" => their_char,
            "won" => game["winnerId"] == our_entrant_id
          }
        ]
      else
        []
      end
    end)
  end

  defp character_selection?(selection), do: selection["selectionType"] == "CHARACTER"

  defp characters(scored) do
    scored
    |> Enum.flat_map(fn set ->
      Enum.map(set["characters"], fn name -> {name, set["won"]} end)
    end)
    |> Enum.group_by(fn {name, _} -> name end)
    |> Enum.map(fn {name, entries} ->
      %{
        "name" => name,
        "games" => length(entries),
        "wins" => Enum.count(entries, fn {_, won} -> won end)
      }
    end)
    |> Enum.sort_by(fn entry -> {entry["games"], entry["wins"]} end, :desc)
    |> Enum.take(@characters_limit)
  end

  defp matchups(scored) do
    scored
    |> Enum.flat_map(& &1["matchups"])
    |> Enum.group_by(fn m -> {m["character"], m["opponent_character"]} end)
    |> Enum.map(fn {{ours, theirs}, games} ->
      %{
        "character" => ours,
        "opponent_character" => theirs,
        "games" => length(games),
        "wins" => Enum.count(games, & &1["won"])
      }
    end)
    |> Enum.sort_by(fn m -> {m["games"], m["character"], m["opponent_character"]} end, :desc)
  end

  # A rectangular grid: rows are our characters, columns the opponents'.
  # Cells with zero games mean "insufficient game data" (rendered as —).
  defp matchup_grid(matchups) do
    columns =
      matchups |> Enum.map(& &1["opponent_character"]) |> Enum.uniq() |> Enum.sort()

    rows =
      matchups
      |> Enum.map(& &1["character"])
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn ours ->
        cells =
          Enum.map(columns, fn theirs ->
            case Enum.find(
                   matchups,
                   &(&1["character"] == ours and &1["opponent_character"] == theirs)
                 ) do
              nil -> %{"opponent_character" => theirs, "games" => 0, "wins" => 0}
              matchup -> matchup
            end
          end)

        %{"character" => ours, "cells" => cells}
      end)

    %{"columns" => columns, "rows" => rows}
  end

  defp opponents(scored) do
    scored
    |> Enum.group_by(fn set ->
      case set["opponent_player_id"] do
        nil -> {:name, set["opponent"]}
        id -> {:id, id}
      end
    end)
    |> Enum.map(fn {key, sets} ->
      wins = Enum.count(sets, & &1["won"])

      %{
        "name" => hd(sets)["opponent"],
        "opponent_player_id" => opponent_id_for(key),
        "unresolved" => match?({:name, _}, key),
        "wins" => wins,
        "losses" => length(sets) - wins,
        "total" => length(sets)
      }
    end)
    |> Enum.sort_by(fn entry -> entry["total"] end, :desc)
    |> Enum.take(@opponents_limit)
  end

  defp opponent_id_for({:id, id}), do: id
  defp opponent_id_for(_), do: nil

  defp recent_sets(scored) do
    scored
    |> Enum.sort_by(& &1["completed_at"], :desc)
    |> Enum.take(@recent_limit)
  end
end
