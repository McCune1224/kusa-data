defmodule KusaData.SetDetails.Parse do
  @moduledoc """
  Pure normalization of the raw `PlayerSets` payload (string-keyed maps from
  the start.gg response, cached in Redis) into typed per-player aggregates:

    * character usage and win rates (attributed by the player's entrant id),
    * stage frequency and win rates,
    * normalized sets (opponent, score, round, event, games).

  No I/O. Sparse data is handled gracefully: sets/games without reported
  characters or stages simply contribute nothing to those aggregates.
  """

  @doc """
  Parses a raw payload for the player with `user_id`.

  Returns:
  `%{characters: %{name => %{games: n, wins: n}},
     stages: %{name => %{games: n, wins: n}},
     sets: [%{id:, display_score:, round:, completed_at:, event:, games: n,
              has_detail: boolean}]}`
  """
  @spec parse(map, integer) :: map
  def parse(payload, user_id) do
    sets = get_in(payload, ["player", "sets", "nodes"]) || []

    {normalized, aggregates} =
      Enum.reduce(sets, {[], %{characters: %{}, stages: %{}}}, fn set, {acc_sets, agg} ->
        {characters, stages, normalized_set} =
          parse_set(set, user_id, agg.characters, agg.stages)

        {[normalized_set | acc_sets], %{characters: characters, stages: stages}}
      end)

    %{
      characters: aggregates.characters,
      stages: aggregates.stages,
      sets: Enum.reverse(normalized)
    }
  end

  defp parse_set(set, user_id, characters, stages) do
    our_entrant_id = our_entrant_id(set, user_id)
    games = set["games"] || []

    {characters, stages} =
      Enum.reduce(games, {characters, stages}, fn game, {chars, stgs} ->
        chars = tally(chars, our_character(game, our_entrant_id), won?(game, our_entrant_id))
        stgs = tally(stgs, get_in(game, ["stage", "name"]), won?(game, our_entrant_id))
        {chars, stgs}
      end)

    normalized = %{
      id: set["id"],
      display_score: set["displayScore"],
      round: set["fullRoundText"],
      completed_at: set["completedAt"],
      event: get_in(set, ["event", "name"]),
      games: length(games),
      has_detail: games != [] and Enum.any?(games, &character?(&1))
    }

    {characters, stages, normalized}
  end

  # The set slot whose entrant includes our user — that entrant id identifies
  # "our side" in game selections and winnerId comparisons.
  defp our_entrant_id(set, user_id) do
    Enum.find_value(set["slots"] || [], fn slot ->
      entrant = slot["entrant"] || %{}
      participants = entrant["participants"] || []

      if Enum.any?(participants, &(get_in(&1, ["user", "id"]) == user_id)),
        do: entrant["id"]
    end)
  end

  defp our_character(game, our_entrant_id) do
    Enum.find_value(game["selections"] || [], fn selection ->
      if selection["entrant"]["id"] == our_entrant_id and
           selection["selectionType"] == "CHARACTER",
         do: get_in(selection, ["character", "name"])
    end)
  end

  defp character?(game) do
    Enum.any?(game["selections"] || [], &(&1["selectionType"] == "CHARACTER"))
  end

  defp won?(game, our_entrant_id),
    do: not is_nil(our_entrant_id) and game["winnerId"] == our_entrant_id

  defp tally(acc, nil, _won), do: acc

  defp tally(acc, name, won) do
    current = Map.get(acc, name, %{games: 0, wins: 0})
    Map.put(acc, name, %{games: current.games + 1, wins: current.wins + if(won, do: 1, else: 0)})
  end
end
