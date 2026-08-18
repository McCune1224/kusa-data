defmodule KusaDataWeb.DistributionControllerTest do
  use KusaDataWeb.ConnCase, async: false
  use KusaData.Test.Doubles

  alias KusaData.Cache
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  test "calendar returns a timezone-normalized VEVENT", %{conn: conn} do
    tournament =
      Fixtures.tournament(1, %{"slug" => "tournament/calendar-test", "name" => "Calendar Cup"})

    FakeTransport.put(:query, "TournamentDetail", Fixtures.tournament_detail_response(tournament))

    conn = get(conn, "/tournament/calendar-test/calendar.ics")
    assert response(conn, 200) =~ "BEGIN:VCALENDAR"
    assert response_content_type(conn, :calendar) =~ "text/calendar"
    assert response(conn, 200) =~ "SUMMARY:Calendar Cup"
    assert response(conn, 200) =~ "DTSTART:202607"
  end

  test "calendar returns 404 for an unknown tournament", %{conn: conn} do
    FakeTransport.put(:query, "TournamentDetail", %{"data" => %{"tournament" => nil}})

    assert conn |> get("/tournament/missing/calendar.ics") |> response(404) ==
             "Tournament not found"
  end

  test "JSON and RSS feeds include stable ids and ETags", %{conn: conn} do
    node = Fixtures.tournament(1, %{"slug" => "tournament/feed-test"})
    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([node], 1))

    conn = get(conn, "/feed/upcoming.json")
    body = response(conn, 200)
    assert get_resp_header(conn, "etag") != []
    assert body =~ "kusa-data:upcoming"
    assert body =~ "tournament/feed-test"

    Cache.delete(
      "browse:" <>
        Jason.encode!(%{
          mode: "upcoming",
          page: 1,
          from: nil,
          to: nil,
          q: nil,
          results_only: false,
          games: :all,
          zip: nil,
          radius: nil,
          country: nil,
          state: nil
        })
    )

    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([node], 1))
    rss_conn = get(build_conn(), "/feed/upcoming.xml")
    assert response_content_type(rss_conn, :xml) =~ "application/rss+xml"
    assert response(rss_conn, 200) =~ "<rss"
  end
end
