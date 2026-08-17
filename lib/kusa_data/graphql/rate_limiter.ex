defmodule KusaData.GraphQL.RateLimiter do
  @moduledoc """
  Sliding-window rate limiter for start.gg requests.

  Blocks callers in `wait/0` until a slot frees up within the window
  (`limit` requests per `window_ms`, default 60 per minute — under
  start.gg's 80/min cap to leave headroom for retries). Waiteres are served
  FIFO as older timestamps age out of the window.
  """

  use GenServer

  @default_limit 60
  @default_window_ms 60_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
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
    %{state | timestamps: [System.monotonic_time(:millisecond) | state.timestamps]}
  end

  defp prune(state) do
    now = System.monotonic_time(:millisecond)
    timestamps = Enum.reject(state.timestamps, fn ts -> now - ts >= state.window_ms end)
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
