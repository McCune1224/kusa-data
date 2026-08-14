defmodule KusaDataWeb.PlayerLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Cache, Event, Game, Player, Repo, Set, SetDetails, Tournament}

  @detail_payload %{
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
                  "participants" => [%{"user" => %{"id" => 100}}]
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
            "games" => [
              %{
                "orderNum" => 1,
                "winnerId" => 10,
                "entrant1Score" => 4,
                "entrant2Score" => 2,
                "stage" => %{"id" => 1, "name" => "Battlefield"},
                "selections" => [
                  %{
                    "entrant" => %{"id" => 10},
                    "selectionType" => "CHARACTER",
                    "character" => %{"id" => 1, "name" => "Fox"}
                  },
                  %{
                    "entrant" => %{"id" => 20},
                    "selectionType" => "CHARACTER",
                    "character" => %{"id" => 2, "name" => "Marth"}
                  }
                ]
              }
            ]
          }
        ]
      }
    }
  }

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    player =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: 100, player_id: 1000, gamer_tag: "Kusa"})
      )

    rival =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: 200, player_id: 2000, gamer_tag: "Rival"})
      )

    tournament =
      Repo.insert!(Tournament.changeset(%Tournament{}, %{startgg_id: 1, slug: "t-big-melee"}))

    event =
      Repo.insert!(
        Event.changeset(%Event{}, %{
          startgg_id: 1,
          name: "Melee Singles",
          tournament_id: tournament.id,
          game_id: game.id
        })
      )

    Repo.insert!(
      Set.changeset(%Set{}, %{
        startgg_id: 1,
        state: 3,
        completed_at: ~U[2026-01-01 00:00:00Z],
        event_id: event.id,
        winner_player_id: player.id,
        loser_player_id: rival.id,
        winner_score: 3,
        loser_score: 1
      })
    )

    Repo.insert!(
      Set.changeset(%Set{}, %{
        startgg_id: 2,
        state: 3,
        completed_at: ~U[2026-01-02 00:00:00Z],
        event_id: event.id,
        winner_player_id: rival.id,
        loser_player_id: player.id,
        winner_score: 3,
        loser_score: 2
      })
    )

    # No Redis in tests: the on-demand fetch bypasses the cache.
    Application.put_env(:kusa_data, Cache, command: fn _commands -> {:error, :down} end)

    Application.put_env(:kusa_data, SetDetails.API,
      fetch: fn _pid, _page, _per -> {:ok, @detail_payload} end
    )

    on_exit(fn ->
      Application.delete_env(:kusa_data, Cache)
      Application.delete_env(:kusa_data, SetDetails.API)
    end)

    %{player: player, rival: rival}
  end

  test "renders player stats and set history", %{conn: conn, player: player} do
    {:ok, view, _html} = live(conn, ~p"/players/#{player.id}")

    html = view |> element("#player-page") |> render()

    assert html =~ "Kusa"
    assert html =~ "1-1"
    assert html =~ "Rival"
    assert html =~ "Melee Singles"
    assert html =~ "Elo"
  end

  test "renders character and stage breakdowns from on-demand detail", %{
    conn: conn,
    player: player
  } do
    {:ok, view, _html} = live(conn, ~p"/players/#{player.id}")

    html = view |> element("#player-page") |> render()

    assert html =~ "Fox"
    assert html =~ "Battlefield"
    refute html =~ "Marth"
  end

  test "renders a not-found state for unknown players", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/players/999999")
    assert view |> element("#player-page") |> render() =~ "Player not found"
  end
end
