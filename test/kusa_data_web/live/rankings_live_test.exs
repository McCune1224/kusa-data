defmodule KusaDataWeb.RankingsLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Game, Player, Rating, Repo}

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    seed(game, 1, "Mango", 1700)
    seed(game, 2, "Armada", 1600)
    seed(game, 3, "Hungrybox", 1500)

    %{game: game}
  end

  defp seed(game, user_id, tag, elo) do
    player =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: user_id, player_id: user_id * 10, gamer_tag: tag})
      )

    Repo.insert!(
      Rating.changeset(%Rating{}, %{
        game_id: game.id,
        player_id: player.id,
        elo: elo,
        sets: 12,
        wins: 8,
        losses: 4
      })
    )
  end

  test "renders the leaderboard elo-descending with player links", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rankings")

    rows = view |> element("#leaderboard-rows") |> render()

    assert rows =~ "Mango"
    assert rows =~ "Armada"
    assert rows =~ "Hungrybox"
    assert rows =~ ~s(href="/players/)

    order = Regex.run(~r/Mango.*Armada.*Hungrybox/s, rows)
    assert order != nil
  end

  test "filters the table as you type", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rankings")

    view |> element("#rankings-form") |> render_change(%{"query" => "mango"})

    rows = view |> element("#leaderboard-rows") |> render()
    assert rows =~ "Mango"
    refute rows =~ "Armada"
  end

  test "shows an empty state when the filter matches nobody", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rankings")

    view |> element("#rankings-form") |> render_change(%{"query" => "zzzzz"})

    assert view |> element("#rankings-results") |> render() =~ "No players match"
  end

  test "clearing the filter restores the full leaderboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rankings")

    view |> element("#rankings-form") |> render_change(%{"query" => "mango"})
    view |> element("#rankings-form") |> render_change(%{"query" => ""})

    rows = view |> element("#leaderboard-rows") |> render()
    assert rows =~ "Mango"
    assert rows =~ "Armada"
  end
end
