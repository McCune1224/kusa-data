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
  @inflight __MODULE__.Inflight

  @spec fetch(String.t(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), :hit | :miss | :bypass} | {:error, term()}
  def fetch(key, fun), do: fetch(key, @default_ttl, fun)

  @spec fetch(String.t(), non_neg_integer(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), :hit | :miss | :bypass} | {:error, term()}
  def fetch(key, ttl, fun) do
    case command(["GET", key]) do
      {:ok, nil} ->
        claim_or_wait(key, ttl, fun, :miss)

      {:ok, payload} ->
        {:ok, Jason.decode!(payload), :hit}

      {:error, _reason} ->
        claim_or_wait(key, ttl, fun, :bypass)
    end
  end

  defp claim_or_wait(key, ttl, fun, status) do
    ensure_inflight!()

    case Agent.get_and_update(@inflight, fn state ->
           case Map.get(state, key) do
             nil ->
               ref = make_ref()
               {:claimed, Map.put(state, key, {ref, []})}

             {ref, waiters} ->
               {{:waiting, ref}, Map.put(state, key, {ref, waiters ++ [self()]})}
           end
         end) do
      :claimed ->
        result = store(key, ttl, fun, status)
        notify_and_release(key, result)
        result

      {:waiting, ref} ->
        receive do
          {^ref, result} -> result
        after
          30_000 -> store(key, ttl, fun, status)
        end
    end
  end

  defp notify_and_release(key, result) do
    waiters =
      Agent.get_and_update(@inflight, fn state ->
        case Map.pop(state, key) do
          {nil, state} ->
            {[], state}

          {{ref, waiters}, rest} ->
            Enum.each(waiters, &send(&1, {ref, result}))
            {waiters, rest}
        end
      end)

    _ = waiters
    :ok
  end

  defp ensure_inflight! do
    case Process.whereis(@inflight) do
      nil ->
        case Agent.start_link(fn -> %{} end, name: @inflight) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
          _ -> :ok
        end

      _ ->
        :ok
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
