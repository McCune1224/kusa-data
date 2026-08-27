defmodule KusaData.Cache do
  @moduledoc """
  Redis-backed cache in front of expensive start.gg fetches.

  Degrades gracefully: when Redis is unreachable the wrapped function still
  runs and its value is returned uncached (`:bypass`). Only successful
  results are stored, so upstream errors are never served from cache.
  Values must be JSON-safe (start.gg payloads qualify).

  Commands dispatch through the configured `:command` implementation
  (defaults to `KusaData.Redis.command/1`), which tests replace with an
  in-memory fake.
  """

  @default_ttl 300

  @spec fetch(String.t(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), :hit | :miss | :bypass} | {:error, term()}
  def fetch(key, fun), do: fetch(key, @default_ttl, fun)

  @spec fetch(String.t(), non_neg_integer(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), :hit | :miss | :bypass} | {:error, term()}
  def fetch(key, ttl, fun) do
    case command(["GET", key]) do
      {:ok, nil} ->
        store(key, ttl, fun, :miss)

      {:ok, payload} ->
        {:ok, Jason.decode!(payload), :hit}

      {:error, _reason} ->
        store(key, ttl, fun, :bypass)
    end
  end

  @spec get(String.t()) :: {:ok, term() | nil} | {:error, term()}
  def get(key) do
    case command(["GET", key]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, payload} -> {:ok, Jason.decode!(payload)}
      error -> error
    end
  end

  @spec put(String.t(), non_neg_integer(), term()) :: :ok | {:error, term()}
  def put(key, ttl, value) do
    case command(["SET", key, Jason.encode!(value), "EX", ttl]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(key) do
    case command(["DEL", key]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp store(key, ttl, fun, status) do
    case fun.() do
      {:ok, value} ->
        if status == :miss, do: put(key, ttl, value)
        {:ok, value, status}

      {:error, _reason} = error ->
        error
    end
  end

  defp command(commands) do
    dispatcher().(commands)
  end

  defp dispatcher do
    case Application.get_env(:kusa_data, __MODULE__, []) |> Keyword.get(:command) do
      nil -> &KusaData.Redis.command/1
      {mod, fun} when is_atom(mod) and is_atom(fun) -> &apply(mod, fun, [&1])
      {mod, fun, args} when is_list(args) -> fn cmd -> apply(mod, fun, args ++ [cmd]) end
      fun when is_function(fun, 1) -> fun
    end
  end
end
