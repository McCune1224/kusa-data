defmodule KusaData.StatsTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Stats
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10)
    )

    :ok
  end

  test "computes and caches stats from the player's set pages" do
    FakeTransport.put(:query, "PlayerSets", fn
      1 -> Fixtures.player_sets_response([Fixtures.set(1, 1, 2, 1), Fixtures.set(2, 1, 2, 2)], 51)
      2 -> Fixtures.player_sets_response([Fixtures.set(3, 1, 2, 1)], 51)
    end)

    assert {:ok, stats, :miss} = Stats.for_player(100)
    assert stats["gamer_tag"] == "Mango"
    assert stats["completed_sets"] == 3
    assert stats["wins"] == 2

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response([], 0))
    assert {:ok, %{"wins" => 2}, :hit} = Stats.for_player(100)
  end

  test "clear_cache forces a fresh computation" do
    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response([], 0))

    assert {:ok, _, :miss} = Stats.for_player(100)
    assert {:ok, _, :hit} = Stats.for_player(100)

    :ok = Stats.clear_cache(100)

    FakeTransport.put(
      :query,
      "PlayerSets",
      Fixtures.player_sets_response([Fixtures.set(1, 1, 2, 1)], 1)
    )

    assert {:ok, %{"wins" => 1}, :miss} = Stats.for_player(100)
  end

  test "propagates identity errors" do
    FakeTransport.put(:query, "PlayerIdentity", %{"data" => %{"player" => nil}})
    assert {:error, :not_found} = Stats.for_player(999)
  end
end
