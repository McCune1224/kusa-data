defmodule KusaData.SetDetails.ParseTest do
  use ExUnit.Case, async: true

  alias KusaData.SetDetails.Parse

  @our_user 100

  defp payload(games \\ []) do
    %{
      "player" => %{
        "sets" => %{
          "nodes" => [
            %{
              "id" => 1,
              "displayScore" => "Kusa 3 - Rival 1",
              "fullRoundText" => "Winners Semis",
              "completedAt" => 1_750_000_000,
              "event" => %{"name" => "Big Melee"},
              "slots" => [
                %{
                  "entrant" => %{
                    "id" => 10,
                    "name" => "Kusa",
                    "participants" => [%{"user" => %{"id" => @our_user}}]
                  }
                },
                %{
                  "entrant" => %{
                    "id" => 20,
                    "name" => "Rival",
                    "participants" => [%{"user" => %{"id" => 999}}]
                  }
                }
              ],
              "games" => games
            }
          ]
        }
      }
    }
  end

  defp game(winner_id, stage, chars) do
    %{
      "orderNum" => 1,
      "winnerId" => winner_id,
      "entrant1Score" => 4,
      "entrant2Score" => 2,
      "stage" => %{"id" => 1, "name" => stage},
      "selections" => chars
    }
  end

  defp selection(entrant_id, character) do
    %{
      "entrant" => %{"id" => entrant_id},
      "selectionType" => "CHARACTER",
      "character" => %{"id" => 1, "name" => character}
    }
  end

  test "tallies character usage and win rates for the player's side" do
    games = [
      game(10, "Battlefield", [selection(10, "Fox"), selection(20, "Marth")]),
      game(20, "Final Destination", [selection(10, "Fox"), selection(20, "Falco")]),
      game(10, "Yoshi's Story", [selection(10, "Sheik"), selection(20, "Falco")])
    ]

    result = Parse.parse(payload(games), @our_user)

    assert result.characters == %{
             "Fox" => %{games: 2, wins: 1},
             "Sheik" => %{games: 1, wins: 1}
           }

    assert result.stages == %{
             "Battlefield" => %{games: 1, wins: 1},
             "Final Destination" => %{games: 1, wins: 0},
             "Yoshi's Story" => %{games: 1, wins: 1}
           }
  end

  test "sets without game data produce empty aggregates but still normalize" do
    result = Parse.parse(payload([]), @our_user)

    assert result.characters == %{}
    assert result.stages == %{}

    assert [%{id: 1, display_score: "Kusa 3 - Rival 1", round: "Winners Semis", games: 0}] =
             result.sets
  end

  test "empty payload parses to empty aggregates" do
    assert Parse.parse(%{"player" => %{"sets" => %{"nodes" => []}}}, @our_user) == %{
             characters: %{},
             stages: %{},
             sets: []
           }
  end

  test "nil payloads degrade to empty aggregates" do
    assert Parse.parse(%{}, @our_user) == %{characters: %{}, stages: %{}, sets: []}
  end

  test "games without our character skip the character tally but keep stages" do
    games = [game(10, "Battlefield", [selection(20, "Marth")])]
    result = Parse.parse(payload(games), @our_user)

    assert result.characters == %{}
    assert result.stages == %{"Battlefield" => %{games: 1, wins: 1}}
  end
end
