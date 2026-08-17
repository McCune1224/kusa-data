defmodule KusaDataWeb.EventLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  setup do
    event = %{
      "id" => 100,
      "name" => "Melee Singles",
      "slug" => "tournament/test-melee-weekly/event/melee-singles",
      "numEntrants" => 3,
      "state" => "COMPLETED",
      "tournament" => %{"id" => 1, "name" => "Test Melee Weekly", "slug" => "test-melee-weekly"}
    }

    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(event))

    :ok
  end

  test "seeds tab lists entrants with seed badges", %{conn: conn} do
    entrants = [
      Fixtures.entrant(11, "Mango", 1, 6126),
      Fixtures.entrant(12, "Armada", 2),
      Fixtures.entrant(13, "Hbox", 3, 6127)
    ]

    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response(entrants))

    {:ok, view, _html} = live(conn, "/event/100?tab=seeds")

    assert wait_has_element(view, "#row-11")
    assert element(view, "h1") |> render() =~ "Melee Singles"
    assert has_element?(view, "#rows")
    assert has_element?(view, "#row-13")
  end

  test "seeds and results rows link the entrant name to player profiles", %{conn: conn} do
    entrants = [
      Fixtures.entrant(11, "Mango", 1, 6126),
      Fixtures.entrant(12, "Armada", 2)
    ]

    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response(entrants))

    {:ok, view, _html} = live(conn, "/event/100?tab=seeds")

    assert wait_has_element(view, "#row-11 a[href='/player/6126']")
    assert element(view, "#row-11 a[href='/player/6126']") |> render() =~ "Mango"
    refute has_element?(view, "#row-12 a[href]")
  end

  test "results tab shows placements and top-8 badges", %{conn: conn} do
    standings = [
      Fixtures.standing(11, "Mango", 1, 6126),
      Fixtures.standing(12, "Armada", 2, 6127),
      Fixtures.standing(13, "Hbox", 3),
      Fixtures.standing(14, "Plup", 5, 6128)
    ]

    FakeTransport.put(:query, "EventResults", Fixtures.results_response(standings))

    {:ok, view, _html} = live(conn, "/event/100?tab=results")

    assert wait_has_element(view, "#row-11")
    assert has_element?(view, "#row-14")
    assert render(view) =~ "Top 8"
    assert wait_has_element(view, "#row-11 a[href='/player/6126']")
    refute has_element?(view, "#row-13 a[href]")
  end

  test "filter narrows the seed list", %{conn: conn} do
    entrants = [
      Fixtures.entrant(11, "Mango", 1),
      Fixtures.entrant(12, "Falco Player", 2)
    ]

    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response(entrants))

    {:ok, view, _html} = live(conn, "/event/100?tab=seeds")

    assert wait_has_element(view, "#row-11")
    assert has_element?(view, "#row-12")

    render_change(view, "filter", %{"filter" => "falco"})

    refute has_element?(view, "#row-11")
    assert has_element?(view, "#row-12")
  end

  test "shows an empty state for unknown events", %{conn: conn} do
    FakeTransport.put(:query, "EventDetail", %{"data" => %{"event" => nil}})

    {:ok, view, _html} = live(conn, "/event/999?tab=seeds")

    assert wait_has_element(view, "h3")
    assert element(view, "h3") |> render() =~ "No event with that id or slug was found"
  end
end
