defmodule KusaDataWeb.API.EventControllerTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    FakeTransport.put(:query, "EventDetail", Fixtures.event_detail_response(Fixtures.event(100)))
    :ok
  end

  test "seeds export returns JSON rows with deterministic columns", %{conn: conn} do
    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([Fixtures.entrant(11, "Mango", 1, 501)])
    )

    conn = get(conn, "/api/events/100/seeds")
    assert json_response(conn, 200)
    assert Enum.at(conn.resp_body |> Jason.decode!(), 0)["entrant_id"] == 11
    assert Enum.at(conn.resp_body |> Jason.decode!(), 0)["seed"] == 1
  end

  test "results export supports CSV with header row", %{conn: conn} do
    FakeTransport.put(
      :query,
      "EventResults",
      Fixtures.results_response([Fixtures.standing(11, "Mango, The", 1, 501)])
    )

    conn = get(conn, "/api/events/100/results?format=csv")
    assert response_content_type(conn, :csv)
    body = response(conn, 200)

    assert body =~ "entrant_id,name,player_id,placement"
    assert body =~ ~s("Mango, The")
  end

  test "sets export flattens both slots", %{conn: conn} do
    FakeTransport.put(
      :query,
      "EventSets",
      Fixtures.event_sets_response([Fixtures.event_set(1, 11, [11, 12])])
    )

    conn = get(conn, "/api/events/100/sets")
    [row] = json_response(conn, 200)
    assert row["winner_id"] == 11
    assert row["entrant_1_id"] == 11
    assert row["entrant_2_id"] == 12
  end

  test "analytics export includes W/L and seed deltas", %{conn: conn} do
    FakeTransport.put(
      :query,
      "EventSeeding",
      Fixtures.seeding_response([Fixtures.entrant(11, "Mango", 4, 501)])
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

    conn = get(conn, "/api/events/100/analytics")
    rows = json_response(conn, 200)
    row = Enum.find(rows, &(&1["entrant_id"] == 11))
    assert row["seed_delta"] == 3
    assert row["upset"] == true
    assert row["reason"] == "reseeded"
    assert row["wins"] == 1
  end

  test "unknown events return a 404 JSON error", %{conn: conn} do
    FakeTransport.put(:query, "EventDetail", %{"data" => %{"event" => nil}})

    conn = get(conn, "/api/events/unknown-slug/seeds")
    assert json_response(conn, 404)["error"] == "unknown event"
  end

  test "invalid export formats return a 422 JSON error", %{conn: conn} do
    FakeTransport.put(:query, "EventSeeding", Fixtures.seeding_response([]))

    conn = get(conn, "/api/events/100/seeds?format=xlsx")
    assert json_response(conn, 422)["error"] =~ "invalid export format"
  end
end
