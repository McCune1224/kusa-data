defmodule KusaData.Cache do
  @moduledoc """
  Redis cache layer in front of on-demand start.gg fetches. Degrades
  gracefully: when Redis is unavailable (no `REDIS_URL`, connection down, or
  command errors) the wrapped function still runs and its value is returned
  uncached.

  The wrapped function returns `{:ok, value} | {:error, reason}`. Only
  successful values are stored (as JSON), so an upstream error is never
  served from cache. Cached values must be JSON-safe (string-keyed maps from
  the start.gg payloads qualify).

  Commands are dispatched through `KusaData.Cache.Redis.command/1`; tests
  override the dispatcher via `config :kusa_data, KusaData.Cache, :command`.
  """

  @default_ttl 300

  @spec fetch(String.t(), (-> {:ok, term} | {:error, term})) ::
          {:ok, term, :hit | :miss | :bypass} | {:error, term}
  def fetch(key, fun), do: fetch(key, @default_ttl, fun)

  @spec fetch(String.t(), non_neg_integer, (-> {:ok, term} | {:error, term})) ::
          {:ok, term, :hit | :miss | :bypass} | {:error, term}
  def fetch(key, ttl, fun) do
    case command(["GET", key]) do
      {:ok, nil} -> run_uncached(key, ttl, fun, :miss)
      {:ok, payload} -> {:ok, Jason.decode!(payload), :hit}
      {:error, _reason} -> run_uncached(key, ttl, fun, :bypass)
    end
  end

  defp run_uncached(key, ttl, fun, status) do
    case fun.() do
      {:ok, value} ->
        if status == :miss, do: command(["SET", key, Jason.encode!(value), "EX", ttl])
        {:ok, value, status}

      {:error, _reason} = error ->
        error
    end
  end

  defp command(commands) do
    dispatcher =
      Application.get_env(:kusa_data, __MODULE__, [])
      |> Keyword.get(:command, &KusaData.Cache.Redis.command/1)

    dispatcher.(commands)
  end
end
