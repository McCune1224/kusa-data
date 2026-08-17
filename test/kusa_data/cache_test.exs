defmodule KusaData.CacheTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Cache
  alias KusaData.Test.FakeRedis

  use KusaData.Test.Doubles

  test "miss runs the function and stores the result" do
    assert {:ok, %{"a" => 1}, :miss} = Cache.fetch("key:1", 60, fn -> {:ok, %{"a" => 1}} end)

    assert FakeRedis.command(["GET", "key:1"]) == {:ok, ~s({"a":1})}
  end

  test "hit returns the stored value without running the function" do
    assert {:ok, %{"a" => 1}, :miss} = Cache.fetch("key:2", 60, fn -> {:ok, %{"a" => 1}} end)

    assert {:ok, %{"a" => 1}, :hit} =
             Cache.fetch("key:2", 60, fn -> flunk("function ran on cache hit") end)
  end

  test "errors are not cached" do
    assert {:error, :boom} = Cache.fetch("key:3", 60, fn -> {:error, :boom} end)

    assert FakeRedis.command(["GET", "key:3"]) == {:ok, nil}
  end

  test "deletes keys" do
    assert {:ok, %{"a" => 1}, :miss} = Cache.fetch("key:4", 60, fn -> {:ok, %{"a" => 1}} end)
    assert :ok = Cache.delete("key:4")
    assert FakeRedis.command(["GET", "key:4"]) == {:ok, nil}
  end

  test "get and put round-trip JSON" do
    assert :ok = Cache.put("key:5", 60, %{"list" => [1, 2, 3]})
    assert {:ok, %{"list" => [1, 2, 3]}} = Cache.get("key:5")
  end
end
