defmodule KusaDataWeb.GameLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Games
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  setup do
    Games.register(%{
      slug: "ultimate",
      videogame_id: 1386,
      name: "Super Smash Bros. Ultimate",
      short_name: "Ultimate"
    })

    :ok
  end

  test "renders the game landing page with game-filtered tournaments", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(1)], 1)
    )

    {:ok, view, _html} = live(conn, "/game/ultimate")

    assert element(view, "h1") |> render() =~ "Super Smash Bros. Ultimate"
    assert wait_has_element(view, "#tournament-1")
  end

  test "unknown game slugs show the not-found state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/game/dota-2")

    assert wait_loaded(view)
    assert element(view, "h3") |> render() =~ "No such game"
  end
end
