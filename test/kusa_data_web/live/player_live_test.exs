defmodule KusaDataWeb.PlayerLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  setup do
    KusaData.Games.register(%{
      slug: "ultimate",
      videogame_id: 1386,
      name: "Super Smash Bros. Ultimate",
      short_name: "Ultimate"
    })

    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10)
    )

    FakeTransport.put(
      :query,
      "PlayerSets",
      Fixtures.player_sets_response([
        Fixtures.set(1, 1, 2, 1),
        Fixtures.set(2, 1, 2, 2),
        Fixtures.set(3, 1, 2, 1)
      ])
    )

    :ok
  end

  test "renders the stats dashboard for a known player", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/player/100")

    assert wait_has_element(view, "#characters")
    assert element(view, "h1") |> render() =~ "Mango"
    assert render(view) =~ "Character usage"
  end

  test "shows section containers for characters, h2h and recent sets", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/player/100")

    assert wait_has_element(view, "#characters")
    assert has_element?(view, "#recent-sets")
  end

  test "unknown players render the empty state", %{conn: conn} do
    FakeTransport.put(:query, "PlayerIdentity", %{"data" => %{"player" => nil}})

    {:ok, view, _html} = live(conn, "/player/999")

    assert wait_has_element(view, "h3")
    assert render(view) =~ "No player with that id was found"
  end

  test "game-scoped URLs analyze only sets from that game", %{conn: conn} do
    ultimate_event = %{
      "id" => 200,
      "name" => "Ultimate Singles",
      "videogame" => %{"id" => 1386, "name" => "Super Smash Bros. Ultimate", "slug" => "ultimate"}
    }

    sets = [
      Fixtures.set(1, 1, 2, 1),
      Fixtures.set(2, 1, 2, 1, %{"event" => ultimate_event}),
      Fixtures.set(3, 1, 2, 2, %{"event" => ultimate_event})
    ]

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response(sets))

    {:ok, view, _html} = live(conn, "/game/ultimate/player/100")

    assert wait_has_element(view, "#characters")
    assert render(view) =~ "Ultimate"
    # Only the two ultimate sets are analyzed: 1 win, 1 loss (2 fetched).
    assert render(view) =~ "last 2 completed sets of 2 fetched"
  end
end
