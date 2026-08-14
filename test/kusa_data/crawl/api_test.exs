defmodule KusaData.Crawl.APITest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias KusaData.Crawl.API

  setup do
    bypass = Bypass.open()

    Application.put_env(:kusa_data, KusaData.GraphQL.Client,
      endpoint: "http://localhost:#{bypass.port}/graphql",
      token: "test-token"
    )

    Application.put_env(:kusa_data, KusaData.GraphQL.RateLimiter,
      limit: 100_000,
      window_ms: 60_000
    )

    %{bypass: bypass}
  end

  defp respond(conn, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  test "pool returns tournament id/slug tuples", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      body = ~s({"data":{"tournaments":{"nodes":[
        {"id": 11, "slug": "/tournament/a"},
        {"id": 12, "slug": "/tournament/b"}
      ]}}})
      respond(conn, body)
    end)

    assert {:ok, [%{id: 11, slug: "/tournament/a"}, %{id: 12, slug: "/tournament/b"}]} =
             API.get_pool(1, 1_700_000_000, 30, 1, 1_700_604_800)
  end

  test "game event prefers singles bracket", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      body = ~s({"data":{"tournament":{"events":[
        {"id": 5, "name": "Melee Doubles"},
        {"id": 6, "name": "Melee Singles"},
        {"id": 7, "name": "Crew Battle"}
      ]}}})
      respond(conn, body)
    end)

    assert {:ok, 6} = API.get_game_event("/tournament/foo", 1)
  end

  test "game event falls back to first event when no singles", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      body = ~s({"data":{"tournament":{"events":[
        {"id": 9, "name": "Doubles"}
      ]}}})
      respond(conn, body)
    end)

    assert {:ok, 9} = API.get_game_event("/tournament/foo", 1)
  end

  test "game event returns error when tournament has no events", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      respond(conn, ~s({"data":{"tournament":{"events":[]}}}))
    end)

    assert :error = API.get_game_event("/tournament/foo", 1)
  end

  test "event sets returns parsed sets and total pages", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      body = ~s({"data":{"event":{"id": 5, "name":"Singles","sets":{
        "pageInfo":{"total":2,"totalPages":1},
        "nodes":[
          {"id": 100, "state":3,"completedAt":"2023-01-01T12:00:00Z","slots":[]},
          {"id": 101, "state":3,"completedAt":"2023-01-02T12:00:00Z","slots":[]}
        ]
      }}}})
      respond(conn, body)
    end)

    assert {:ok, sets, 1} = API.get_event_sets(5, 1, 50)
    assert length(sets) == 2
    assert [%{"id" => 100}, %{"id" => 101}] = sets
  end

  test "event sets returns empty when event is null", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> respond(conn, ~s({"data":{"event":null}})) end)
    assert {:ok, [], 0} = API.get_event_sets(999, 1, 50)
  end
end
