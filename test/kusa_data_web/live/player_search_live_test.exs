defmodule KusaDataWeb.PlayerSearchLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Game, Player, Rating, Repo, Search}

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    seed(game, 1, "Mango", 1700)
    seed(game, 2, "MangoTheBeast", 1600)

    Application.put_env(:kusa_data, Search, live_scan: fn _q -> [] end)
    on_exit(fn -> Application.delete_env(:kusa_data, Search) end)

    %{}
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
        sets: 1,
        wins: 1,
        losses: 0
      })
    )
  end

  test "renders ranked results for a query param", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/players?q=mango")

    assert html =~ "Mango"
    assert html =~ "MangoTheBeast"
    assert html =~ ~s(href="/players/)
  end

  test "renders an empty prompt without a query", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/players")

    assert html =~ "Search for a player"
  end

  test "renders a no-results empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/players?q=zzzzz")
    assert view |> element("#search-results") |> render() =~ "No players found"
  end
end
