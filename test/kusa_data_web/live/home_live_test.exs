defmodule KusaDataWeb.HomeLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  test "renders hero with both search forms and a skeleton-free feed", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(1), Fixtures.tournament(2)], 2)
    )

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#nearby-form")
    assert has_element?(view, "#link-jump-form")
    assert wait_has_element(view, "#tournaments")
  end

  test "streams upcoming tournament cards into the grid", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response(
        [Fixtures.tournament(1, %{"name" => "Test Melee Weekly"})],
        1
      )
    )

    {:ok, view, _html} = live(conn, "/")

    assert wait_has_element(view, "#tournament-1")
    assert element(view, "#tournament-1") |> render() =~ "Test Melee Weekly"
  end

  test "nearby search attaches the resolved place and renders cards", %{conn: conn} do
    FakeTransport.put(
      :url,
      "zippopotam.us/us/60614",
      Fixtures.zippopotam_response(41.9208, -87.6488, "Chicago", "IL")
    )

    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(7)], 1)
    )

    {:ok, view, _html} = live(conn, "/?zip=60614&radius=50mi")

    assert wait_has_element(view, "#tournament-7")
    assert render(view) =~ "Melee near"
    assert render(view) =~ "Chicago"
  end

  test "shows an empty state when no tournaments come back", %{conn: conn} do
    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([], 0))

    {:ok, view, _html} = live(conn, "/")

    assert wait_loaded(view)
    refute has_element?(view, "#tournaments")
    assert element(view, "h3") |> render() =~ "No tournaments found"
  end
end
