defmodule KusaData.GraphQL.RateLimiter do
  @moduledoc """
  Sliding-window rate limiter for start.gg requests.

  Provides a non-blocking `check/0` that returns `{:ok, remaining}` or
  `{:wait, ms}` so callers can poll independently without serializing
  through a single GenServer call. Also provides `acquire/0` for callers
  that prefer to block.
  """

  use GenServer

  @default_limit 60
  @default_window_ms 60_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Non-blocking slot check. Returns `{:ok, remaining_slots}` if a slot is
  available (and immediately consumes one), or `{:wait, ms}` with the
  milliseconds until the next slot frees up.
  """
  @spec check(GenServer.server()) :: {:ok, non_neg_integer()} | {:wait, pos_integer()}
  def check(limiter \\ __MODULE__) do
    GenServer.call(limiter, :check, 5_000)
  end

  @doc "Blocks the caller until a request slot is available."
  @spec wait(GenServer.server()) :: :ok
  def wait(limiter \\ __MODULE__) do
    GenServer.call(limiter, :wait, :infinity)
  end

  @impl true
  def init(opts) do
    env = Application.get_env(:kusa_data, __MODULE__, [])
    limit = Keyword.get(opts, :limit) || Keyword.get(env, :limit) || @default_limit

    window_ms =
      Keyword.get(opts, :window_ms) || Keyword.get(env, :window_ms) || @default_window_ms

    state = %{
      limit: limit,
      window_ms: window_ms,
      timestamps: [],
      pending: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:check, _from, state) do
    state = prune(state)
    remaining = state.limit - length(state.timestamps)

    if remaining > 0 do
      {:reply, {:ok, remaining}, %{state | timestamps: [now() | state.timestamps]}}
    else
      wait_ms = wait_ms(state)
      {:reply, {:wait, wait_ms}, state}
    end
  end

  @impl true
  def handle_call(:wait, from, state) do
    state = prune(state)

    if length(state.timestamps) < state.limit do
      {:noreply, grant(from, state)}
    else
      {:noreply, %{state | pending: :queue.in(from, state.pending)}}
    end
  end

  @impl true
  def handle_info(:release, state) do
    {:noreply, drain(prune(state))}
  end

  defp grant(from, state) do
    Process.send_after(self(), :release, state.window_ms)
    GenServer.reply(from, :ok)
    %{state | timestamps: [now() | state.timestamps]}
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp wait_ms(%{timestamps: []}), do: 100

  defp wait_ms(%{timestamps: timestamps, window_ms: window_ms}) do
    oldest = List.last(timestamps)
    max(100, window_ms - (now() - oldest))
  end

  defp prune(state) do
    cutoff = now() - state.window_ms
    timestamps = Enum.reject(state.timestamps, fn ts -> ts < cutoff end)
    %{state | timestamps: timestamps}
  end

  defp drain(state) do
    case :queue.out(state.pending) do
      {:empty, _pending} ->
        state

      {{:value, from}, pending} ->
        if length(state.timestamps) < state.limit do
          state = Map.put(state, :pending, pending)
          drain(grant(from, state))
        else
          state
        end
    end
  end
end
