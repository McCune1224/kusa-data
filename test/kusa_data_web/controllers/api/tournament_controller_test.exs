defmodule KusaDataWeb.API.TournamentControllerTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    tournament =
      Fixtures.tournament(1, %{
        "slug" => "tournament/test-melee-weekly",
        "events" => [%{"id" => 100, "numEntrants" => 32, "state" => 3}]
      })

    FakeTransport.put(:query, "TournamentDetail", Fixtures.tournament_detail_response(tournament))
    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(Fixtures.event(100)))

    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([Fixtures.entrant(11, "Mango", 1, 501)])
    )

    FakeTransport.put(
      :query,
      "EventResults",
      Fixtures.results_response([Fixtures.standing(11, "Mango", 1, 501)])
    )

    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([Fixtures.event_set(1, 11, [11, 12])])
    )

    :ok
  end

  test "export returns the full tournament with per-event analytics as JSON", %{conn: conn} do
    conn = get(conn, "/api/tournaments/test-melee-weekly/export")
    data = json_response(conn, 200)

    assert data["tournament"]["name"] == "Test Melee Weekly"
    assert [event] = data["events"]
    assert event["analysis"]["entrant_count"] == 2
    assert event["analysis"]["match_count"] == 1
  end

  test "export renders a deterministic CSV across events", %{conn: conn} do
    conn = get(conn, "/api/tournaments/test-melee-weekly/export?format=csv")
    assert response_content_type(conn, :csv)
    body = response(conn, 200)

    assert body =~
             "event_id,event_name,tournament_name,entrant_id,entrant_name,player_id,seed,placement,seed_delta,upset,reason,wins,losses,sets_played,games_won,games_lost"

    assert body =~ "100,Melee Singles,Test Melee Weekly,11,Mango,501,1,1,0,false,"
  end

  test "unknown tournaments return a 404 JSON error", %{conn: conn} do
    FakeTransport.put(:query, "TournamentDetail", %{"data" => %{"tournament" => nil}})

    conn = get(conn, "/api/tournaments/nope/export")
    assert json_response(conn, 404)["error"] == "unknown tournament"
  end

  test "invalid export formats return a 422 JSON error", %{conn: conn} do
    conn = get(conn, "/api/tournaments/test-melee-weekly/export?format=pdf")
    assert json_response(conn, 422)["error"] =~ "invalid export format"
  end
end
