defmodule KusaData.SetDetails.APITest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias KusaData.{Cache, SetDetails}

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

    on_exit(fn ->
      Application.delete_env(:kusa_data, KusaData.GraphQL.Client)
      Application.delete_env(:kusa_data, KusaData.GraphQL.RateLimiter)
    end)

    %{bypass: bypass}
  end

  defp respond(conn, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  test "for_player returns the parsed start.gg payload", %{bypass: bypass} do
    payload = ~s({"data":{"player":{"id":42,"sets":{"nodes":[{"id":7,"state":3}]}}}})

    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      assert body =~ "query PlayerSets"
      assert body =~ ~s("playerId":42)
      assert body =~ ~s("page":1)
      assert body =~ ~s("perPage":20)
      respond(conn, payload)
    end)

    assert {:ok, %{"player" => %{"sets" => %{"nodes" => [%{"id" => 7}]}}}} =
             SetDetails.API.for_player(42, 1, 20)
  end

  test "for_player surfaces upstream http errors", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> send_resp(conn, 500, "boom") end)
    assert {:error, {:http, 500}} = SetDetails.API.for_player(42, 1, 20)
  end

  test "for_player serves cached payloads without hitting start.gg", %{bypass: bypass} do
    cached = ~s({"player":{"id":42,"sets":{"nodes":[{"id":99}]}}})
    Application.put_env(:kusa_data, Cache, command: fn _commands -> {:ok, cached} end)
    on_exit(fn -> Application.delete_env(:kusa_data, Cache) end)

    assert {:ok, %{"player" => %{"sets" => %{"nodes" => [%{"id" => 99}]}}}} =
             SetDetails.API.for_player(42, 1, 20)
  end
end
