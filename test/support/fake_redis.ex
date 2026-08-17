defmodule KusaData.Test.FakeRedis do
  @moduledoc """
  In-memory stand-in for `KusaData.Redis`, installed via
  `config :kusa_data, KusaData.Cache, command: {__MODULE__, :command}`.

  Supports the GET/SET/DEL subset the cache uses. State is a plain Agent
  started per-test with `start_supervised!`.
  """

  use Agent

  @name __MODULE__

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  def command(commands) do
    case commands do
      ["GET", key] -> {:ok, get(key)}
      ["SET", key, value, "EX", ttl] -> store(key, value, ttl)
      ["DEL", key] -> {:ok, delete(key)}
      other -> {:error, {:unsupported, other}}
    end
  end

  defp get(key) do
    current = now()

    Agent.get(@name, fn state ->
      case Map.get(state, key) do
        %{value: value, expires_at: expires_at} when expires_at > current -> value
        _ -> nil
      end
    end)
  end

  defp store(key, value, ttl) do
    Agent.update(@name, &Map.put(&1, key, %{value: value, expires_at: now() + ttl}))
    {:ok, "OK"}
  end

  defp delete(key) do
    Agent.get_and_update(@name, fn state ->
      if Map.has_key?(state, key), do: {1, Map.delete(state, key)}, else: {0, state}
    end)
  end

  defp now, do: System.monotonic_time(:millisecond)
end
