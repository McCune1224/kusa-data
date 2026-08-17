defmodule KusaData.PlayersTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Players
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  test "profile returns identity and caches it" do
    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10)
    )

    assert {:ok, identity, :miss} = Players.profile(100)
    assert identity["gamer_tag"] == "Mango"
    assert identity["user_id"] == 10

    FakeTransport.put(:query, "PlayerIdentity", %{"data" => %{"player" => nil}})
    assert {:ok, %{"gamer_tag" => "Mango"}, :hit} = Players.profile(100)
  end

  test "profile returns not_found when player is nil" do
    FakeTransport.put(:query, "PlayerIdentity", %{"data" => %{"player" => nil}})

    assert {:error, :not_found} = Players.profile(999)
  end
end
