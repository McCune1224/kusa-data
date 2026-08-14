defmodule KusaData.CacheTest do
  use ExUnit.Case, async: false

  alias KusaData.Cache

  setup do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    Application.put_env(:kusa_data, Cache,
      command: fn commands ->
        Agent.update(agent, &[commands | &1])
        {:ok, nil}
      end
    )

    on_exit(fn -> Application.delete_env(:kusa_data, Cache) end)
    %{agent: agent}
  end

  defp recorded(agent) do
    agent |> Agent.get(& &1) |> Enum.reverse()
  end

  test "hit returns the cached value without running the function" do
    Application.put_env(:kusa_data, Cache,
      command: fn
        ["GET", "k"] -> {:ok, ~s({"ok":true})}
        _other -> {:error, :unexpected_command}
      end
    )

    assert {:ok, %{"ok" => true}, :hit} = Cache.fetch("k", fn -> raise "must not run" end)
  end

  test "miss runs the function and stores the value with the given ttl", %{agent: agent} do
    fun = fn -> {:ok, %{"answer" => 42}} end

    assert {:ok, %{"answer" => 42}, :miss} = Cache.fetch("k", 600, fun)

    assert recorded(agent) == [
             ["GET", "k"],
             ["SET", "k", ~s({"answer":42}), "EX", 600]
           ]
  end

  test "an errored result is returned but never cached", %{agent: agent} do
    assert {:error, :upstream} = Cache.fetch("k", 600, fn -> {:error, :upstream} end)
    assert recorded(agent) == [["GET", "k"]]
  end

  test "bypass runs the function uncached when redis is unavailable" do
    Application.put_env(:kusa_data, Cache, command: fn _commands -> {:error, :down} end)
    assert {:ok, :value, :bypass} = Cache.fetch("k", fn -> {:ok, :value} end)
  end

  test "default ttl applies when fetch/2 is used", %{agent: agent} do
    Cache.fetch("k", fn -> {:ok, :value} end)

    assert recorded(agent) == [
             ["GET", "k"],
             ["SET", "k", ~s("value"), "EX", 300]
           ]
  end
end
