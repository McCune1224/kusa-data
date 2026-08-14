defmodule KusaDataWeb.HomeLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Game, Player, Rating, Repo}

  setup do
    game =
      Repo.insert!(
        Game.changeset(%Game{}, %{
          key: "melee",
          name: "Melee",
          videogame_id: 1
        })
      )

    seed_player(game, 1, "Mango", nil)
    seed_player(game, 2, "MangoTheBeast", "C9")
    seed_player(game, 3, "LeffenDogSquad", nil)

    %{game: game}
  end

  defp seed_player(game, user_id, tag, prefix) do
    player =
      Repo.insert!(
        Player.changeset(%Player{}, %{
          user_id: user_id,
          player_id: user_id * 10,
          gamer_tag: tag,
          prefix: prefix
        })
      )

    Repo.insert!(
      Rating.changeset(%Rating{}, %{
        game_id: game.id,
        player_id: player.id,
        elo: 1000 + user_id * 100,
        sets: 5,
        wins: 3,
        losses: 2
      })
    )

    player
  end

  test "renders the search box and no results initially", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")
    assert html =~ "Melee tournament analytics"
    assert html =~ "Search players by gamer tag or prefix"
    refute view |> element("[data-test=results]") |> render() =~ "Mango"
  end

  test "shows ranked dropdown results as the user types", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#search-form")
    |> render_change(%{"query" => "mango"})

    results = view |> element("[data-test=results]") |> render()
    # Exact tag first, then tag-prefix, then substring with prefix bonus
    assert results =~ "Mango"
    assert results =~ "MangoTheBeast"
    assert results =~ "Elo"
  end

  test "shows no-match hint when index has nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#search-form")
    |> render_change(%{"query" => "zzzzz"})

    html = view |> element("[data-test=results]") |> render()
    assert html =~ "No matches yet"
  end

  test "hides results once the box is emptied", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#search-form")
    |> render_change(%{"query" => "mango"})

    assert view |> element("[data-test=results]") |> render() =~ "Mango"

    view
    |> element("#search-form")
    |> render_change(%{"query" => ""})

    refute view |> element("[data-test=results]") |> render() =~ "Mango"
    refute view |> element("[data-test=results]") |> render() =~ "No matches"
  end
end
