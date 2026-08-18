defmodule KusaDataWeb.RegionLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  test "renders the region index derived from recent tournaments", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response(
        [
          Fixtures.tournament(1, %{"countryCode" => "US", "addrState" => "IL"}),
          Fixtures.tournament(2, %{"countryCode" => "US", "addrState" => "CA"}),
          Fixtures.tournament(3, %{"countryCode" => "CA", "addrState" => "ON"})
        ],
        3
      )
    )

    {:ok, view, _html} = live(conn, "/regions")

    assert wait_loaded(view)
    assert has_element?(view, "a[href='/region/US/IL']")
    assert has_element?(view, "a[href='/region/US/CA']")
    assert has_element?(view, "a[href='/region/CA/ON']")
  end

  test "renders a country-level entry when state is missing", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response(
        [Fixtures.tournament(1, %{"countryCode" => "US", "addrState" => nil})],
        1
      )
    )

    {:ok, view, _html} = live(conn, "/regions")

    assert wait_loaded(view)
    assert has_element?(view, "a[href='/region/US']")
  end

  test "region listing filters tournaments by country and state", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(7)], 1)
    )

    {:ok, view, _html} = live(conn, "/region/US/IL")

    assert wait_has_element(view, "#tournament-7")
    assert render(view) =~ "US / IL"
    assert element(view, "h1") |> render() =~ "US / IL"
  end

  test "region listing shows an empty state for quiet regions", %{conn: conn} do
    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([], 0))

    {:ok, view, _html} = live(conn, "/region/GB/ENG")

    assert wait_loaded(view)
    assert element(view, "h3") |> render() =~ "No upcoming tournaments here"
  end
end
