defmodule KusaData.Search.APITest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias KusaData.Search.API

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

  defp qname(body) do
    case Regex.run(~r/query (\w+)/, body) do
      [_all, name] -> name
      _ -> "NOQ"
    end
  end

  defp respond(conn, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  test "recent_tournaments returns slugs", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      assert qname(body) == "RecentTournaments"
      respond(conn, ~s({"data":{"tournaments":{"nodes":[{"slug":"/t/a"},{"slug":"/t/b"}]}}}))
    end)

    assert {:ok, ["/t/a", "/t/b"]} = API.recent_tournaments(1_700_000_000, 25)
  end

  test "recent_tournaments returns empty on null nodes", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> respond(conn, ~s({"data":{"tournaments":null}})) end)
    assert {:ok, []} = API.recent_tournaments(1_700_000_000, 25)
  end

  test "search_participants parses player nodes with user ids", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      assert qname(body) == "SearchParticipants"
      assert body =~ "mango"

      respond(conn, ~s({"data":{"tournament":{"participants":{"nodes":[
        {"id": 5, "gamerTag": "Mango", "prefix": "C9",
          "user": {"id": 100, "player": {"id": 10}}},
        {"id": 6, "gamerTag": "MangoKid", "prefix": null,
          "user": {"id": 200, "player": {"id": 20}}}
      ]}}}}))
    end)

    assert {:ok, results} = API.search_participants("/t/gen", "mango", 10)

    assert Enum.map(results, & &1.user_id) == [100, 200]
    assert Enum.map(results, & &1.gamer_tag) == ["Mango", "MangoKid"]
    assert hd(results).prefix == "C9"
    assert hd(results).player_id == 10
  end

  test "search_participants returns empty on null tournament", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> respond(conn, ~s({"data":{"tournament":null}})) end)
    assert {:ok, []} = API.search_participants("/t/gen", "mango", 10)
  end

  test "search_participants returns empty on graphql/network failure", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      respond(conn, ~s({"errors":[{"message":"boom"}]}))
    end)

    assert {:ok, []} = API.search_participants("/t/gen", "mango", 10)
  end
end
