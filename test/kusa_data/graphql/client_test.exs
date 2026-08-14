defmodule KusaData.GraphQL.ClientTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias KusaData.GraphQL.Client

  setup do
    bypass = Bypass.open()

    Application.put_env(:kusa_data, KusaData.GraphQL.Client,
      endpoint: "http://localhost:#{bypass.port}/graphql",
      token: "test-token",
      retries: 3,
      backoff_ms: 10
    )

    # never block in these tests — the limiter's math is covered separately
    Application.put_env(:kusa_data, KusaData.GraphQL.RateLimiter,
      limit: 100_000,
      window_ms: 60_000
    )

    %{bypass: bypass}
  end

  test "returns parsed data on success", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, ~s({"data":{"player":{"id":1}}}))
    end)

    assert {:ok, %{"player" => %{"id" => 1}}} =
             Client.request("query GetPlayer { player(id: 1) { id } }")
  end

  test "graphql validation/complexity errors are NOT retried", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, ~s({"errors":[{"message":"Cannot query field"}]}))
    end)

    assert {:error, {:graphql, [%{"message" => "Cannot query field"}]}} =
             Client.request("query Bad { nope }")
  end

  test "429 is retried with backoff then succeeds", %{bypass: bypass} do
    counter = :atomics.new(1, signed: false)

    Bypass.expect(bypass, fn conn ->
      if :atomics.add_get(counter, 1, 1) == 1 do
        send_resp(conn, 429, "")
      else
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"data":{"ok":true}}))
      end
    end)

    assert {:ok, %{"ok" => true}} = Client.request("query X { ok }")
  end

  test "429 exhaustion returns rate_limited", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> send_resp(conn, 429, "") end)
    assert {:error, :rate_limited} = Client.request("query X { ok }")
  end

  test "http errors are surfaced", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn -> send_resp(conn, 500, "") end)
    assert {:error, {:http, 500}} = Client.request("query X { ok }")
  end

  test "send bearer token header", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert List.keyfind(conn.req_headers, "authorization", 0) ==
               {"authorization", "Bearer test-token"}

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, ~s({"data":{}}))
    end)

    assert {:ok, %{}} = Client.request("query X { ok }")
  end
end
