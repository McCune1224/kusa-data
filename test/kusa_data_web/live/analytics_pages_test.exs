defmodule KusaDataWeb.AnalyticsPagesTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  setup do
    FakeTransport.put(:query, "PlayerIdentity", fn
      1 -> Fixtures.player_identity_response(100, "Mango", 10)
      _ -> Fixtures.player_identity_response(200, "Armada", 20)
    end)

    FakeTransport.put(:query, "PlayerSets", fn
      1 ->
        Fixtures.player_sets_response([
          Fixtures.set(1, 1, 2, 1),
          Fixtures.set(2, 1, 2, 2),
          Fixtures.set(3, 1, 2, 1)
        ])

      _ ->
        Fixtures.player_sets_response([Fixtures.set(4, 2, 1, 1), Fixtures.set(5, 2, 1, 2)])
    end)

    :ok
  end

  test "history page renders the full set list with filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/player/100/history")

    assert wait_has_element(view, "#history-rows")
    assert has_element?(view, "#history-filter-form")
    assert render(view) =~ "Full match history"
    assert render(view) =~ "Mango"
  end

  test "trend page renders chronological month buckets", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/player/100/trend")

    assert wait_has_element(view, "#trend-buckets")
    assert render(view) =~ "Player trend"
  end

  test "h2h page shows the record between two players", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/player/100/h2h?vs=200")

    assert wait_has_element(view, "#h2h-record")
    assert render(view) =~ "Head-to-head"
    assert render(view) =~ "Mango"
    assert render(view) =~ "Armada"
  end

  test "compare page renders side-by-side players and the h2h panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/players/compare?a=100&b=200")

    assert wait_has_element(view, "#compare-panel")
    assert render(view) =~ "Player comparison"
    assert render(view) =~ "Mango"
    assert render(view) =~ "Armada"
    assert render(view) =~ "Shared events"
  end

  test "rankings page renders the rating table", %{conn: conn} do
    tournament =
      Fixtures.tournament(1, %{
        "slug" => "tournament/test-melee-weekly",
        "events" => [%{"id" => 100, "numEntrants" => 32, "state" => 3}]
      })

    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([tournament], 1)
    )

    FakeTransport.put(:query, "TournamentDetail", Fixtures.tournament_detail_response(tournament))
    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(Fixtures.event(100)))

    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([Fixtures.entrant(11, "Mango", 1, 100)])
    )

    FakeTransport.put(
      :query,
      "EventResults",
      Fixtures.results_response([Fixtures.standing(11, "Mango", 1, 100)])
    )

    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([Fixtures.event_set(1, 11, [11, 12])])
    )

    sets =
      Enum.flat_map(100..102, fn event_id ->
        event = %{
          "id" => event_id,
          "name" => "E#{event_id}",
          "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
        }

        [
          Fixtures.set(1, 1, 2, 1, %{"event" => event}),
          Fixtures.set(2, 1, 2, 2, %{"event" => event}),
          Fixtures.set(3, 1, 2, 1, %{"event" => event})
        ]
      end)

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response(sets))

    # The rankings candidate is the single player id found in the seeding
    # analytics, so pin PlayerIdentity to Mango deterministically instead of
    # relying on the shared attempt-keyed setup fixture (which is consumed by
    # earlier tests in this module and would return Armada).
    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10)
    )

    {:ok, view, _html} = live(conn, "/rankings?game=melee&min_tournaments=3")

    assert wait_has_element(view, "#ranking-rows")
    assert render(view) =~ "Elo power rankings"
    assert has_element?(view, "#rankings-filter-form")
    assert render(view) =~ "Mango"
  end
end
