defmodule KusaDataWeb.HomeRouteTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Game, Repo}

  setup do
    Repo.insert!(
      Game.changeset(%Game{}, %{
        key: "melee",
        name: "Melee",
        videogame_id: 1
      })
    )

    :ok
  end

  test "GET / renders the search LiveView", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Melee tournament analytics"
  end

  test "GET / is live", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Search players by gamer tag or prefix"
  end
end
