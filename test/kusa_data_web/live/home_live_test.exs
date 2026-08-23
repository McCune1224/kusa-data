defmodule KusaDataWeb.HomeLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  defp seed_upcoming(nodes \\ [Fixtures.tournament(1)]) do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response(nodes, length(nodes))
    )
  end

  test "renders hero, browse tabs, and a skeleton-free feed", %{conn: conn} do
    seed_upcoming()

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#nearby-form")
    assert has_element?(view, "#link-jump-form")
    assert wait_has_element(view, "#tournaments")
    assert has_element?(view, "a[href='/?mode=past']")
    assert has_element?(view, "a[href='/?mode=search']")
    assert has_element?(view, "a[href='/regions']")
  end

  test "streams upcoming tournament cards into the grid", %{conn: conn} do
    seed_upcoming([Fixtures.tournament(1, %{"name" => "Test Melee Weekly"})])

    {:ok, view, _html} = live(conn, "/")

    assert wait_has_element(view, "#tournament-1")
    assert element(view, "#tournament-1") |> render() =~ "Test Melee Weekly"
  end

  test "game filter chips render and switch while preserving mode", %{conn: conn} do
    seed_upcoming()

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#game-filter")
    # Melee (the backend default) starts active.
    assert has_element?(view, "#game-filter a.bg-lime-400")

    # Switching to Ultimate keeps the upcoming mode in the URL.
    ultimate_slug = "ultimate"

    KusaData.Games.register(%{
      slug: ultimate_slug,
      videogame_id: 1386,
      name: "Super Smash Bros. Ultimate",
      short_name: "Ultimate"
    })

    {:ok, view, _html} = live(conn, "/?game=ultimate")
    assert wait_has_element(view, "#tournaments")
    assert render(view) =~ "Ultimate"
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
    seed_upcoming([])

    {:ok, view, _html} = live(conn, "/")

    assert wait_loaded(view)
    refute has_element?(view, "#tournaments")
    assert element(view, "h3") |> render() =~ "No tournaments found"
  end

  test "past mode renders the date form and filters by completed tournaments", %{conn: conn} do
    nodes = [
      Fixtures.tournament(1, %{"events" => [%{"id" => 101, "numEntrants" => 8, "state" => 3}]}),
      Fixtures.tournament(2, %{"events" => [%{"id" => 102, "numEntrants" => 8, "state" => 1}]}),
      Fixtures.tournament(3, %{"events" => [%{"id" => 103, "numEntrants" => 8}]})
    ]

    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response(nodes, 3)
    )

    {:ok, view, _html} =
      live(conn, "/?mode=past&from=2026-01-01&to=2026-01-31&results_only=true")

    assert has_element?(view, "#past-form")
    assert wait_has_element(view, "#tournament-1")
    refute has_element?(view, "#tournament-2")
    refute has_element?(view, "#tournament-3")
    assert render(view) =~ "results only"
  end

  test "past form submission patches the URL and re-filters", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(4)], 1)
    )

    {:ok, view, _html} = live(conn, "/?mode=past")

    render_submit(view, "past-search", %{
      "from" => "2026-01-01",
      "to" => "2026-01-31",
      "q" => "genesis",
      "results_only" => "true"
    })

    assert wait_has_element(view, "#tournament-4")
    assert render(view) =~ "genesis"
  end

  test "search mode debounces input and keeps terms in the URL", %{conn: conn} do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(5, %{"name" => "Genesis X"})], 1)
    )

    {:ok, view, _html} = live(conn, "/?mode=search")

    render_change(view, "search-input", %{"q" => "genesis"})

    assert wait_has_element(view, "#tournament-5")
    assert render(view) =~ "Tournament search"
    assert render(view) =~ "matching"
  end

  test "empty search terms show a prompt instead of querying", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/?mode=search")

    assert wait_loaded(view)
    assert element(view, "h3") |> render() =~ "Type to search"
  end

  test "pagination loads the next page without duplicating stream ids", %{conn: conn} do
    page1 = Enum.map(1..24, &Fixtures.tournament/1)

    FakeTransport.put(
      :query,
      "TournamentSearch",
      fn
        1 -> Fixtures.tournament_search_response(page1, 25)
        2 -> Fixtures.tournament_search_response([Fixtures.tournament(25)], 25)
      end
    )

    {:ok, view, _html} = live(conn, "/")

    assert wait_has_element(view, "#tournament-1")
    assert has_element?(view, "#tournament-24")
    refute has_element?(view, "#tournament-25")

    render_click(view, "load-more")

    assert wait_has_element(view, "#tournament-25")
    assert has_element?(view, "#tournament-1")

    html = render(view)
    assert length(Regex.scan(~r/id="tournament-\d+"/, html)) == 25
  end

  test "pasted start.gg links navigate to the canonical route", %{conn: conn} do
    seed_upcoming([])

    {:ok, view, _html} = live(conn, "/")

    render_submit(view, "link-jump", %{
      "link" => "https://www.start.gg/tournament/genesis-x/event/melee-singles?tab=brackets#top"
    })

    assert_redirect(view, "/event/tournament%2Fgenesis-x%2Fevent%2Fmelee-singles")
  end

  test "invalid links flash an error instead of navigating", %{conn: conn} do
    seed_upcoming([])

    {:ok, view, _html} = live(conn, "/")

    render_submit(view, "link-jump", %{"link" => "https://evil.example.com/tournament/foo"})

    assert render(view) =~ "That is not a start.gg link"
  end
end
