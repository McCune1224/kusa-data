defmodule KusaData.GraphQL.ClientTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.GraphQL.Client
  alias KusaData.Test.FakeTransport

  @document "query PlayerIdentity($id: ID!) { player(id: $id) { id } }"

  use KusaData.Test.Doubles

  test "returns data on success" do
    FakeTransport.put(:query, "PlayerIdentity", %{"data" => %{"player" => %{"id" => 1}}})

    assert {:ok, %{"player" => %{"id" => 1}}} = Client.query(@document, %{id: 1})
  end

  test "returns graphql errors as errors" do
    FakeTransport.put(:query, "PlayerIdentity", %{"errors" => [%{"message" => "nope"}]})

    assert {:error, {:graphql, [%{"message" => "nope"}]}} = Client.query(@document, %{id: 1})
  end

  test "retries once on 429 and succeeds on the retry" do
    parent = self()

    response_fn = fn attempt ->
      send(parent, {:attempt, attempt})
      if attempt == 1, do: %{status: 429}, else: %{"data" => %{"player" => %{"id" => 1}}}
    end

    FakeTransport.put(:query, "PlayerIdentity", response_fn)

    assert {:ok, %{"player" => %{"id" => 1}}} = Client.query(@document, %{id: 1})
    assert_receive {:attempt, 1}
    assert_receive {:attempt, 2}
  end

  test "gives up on persistent 429s" do
    FakeTransport.put(:query, "PlayerIdentity", %{status: 429})

    assert {:error, :rate_limited} = Client.query(@document, %{id: 1})
  end

  test "returns other http statuses as errors" do
    FakeTransport.put(:query, "PlayerIdentity", %{status: 500})

    assert {:error, {:http, 500}} = Client.query(@document, %{id: 1})
  end

  test "returns transport failures as errors" do
    FakeTransport.put(:query, "PlayerIdentity", %{error: :network_down})

    assert {:error, :network_down} = Client.query(@document, %{id: 1})
  end
end
