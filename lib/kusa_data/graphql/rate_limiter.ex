defmodule KusaData.GraphQL.RateLimiter do
  @moduledoc """
  GenServer that throttles start.gg requests to `limit` per `window_ms`
  (defaults: 80 per 60s). `wait/0` blocks the caller until a slot is free.
  Config via `:kusa_data, __MODULE__` (overrideable in tests).
  """
  use GenServer

  alias KusaData.GraphQL.RateLimit

  @default_limit 80
  @default_window_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Blocks the caller until a request slot is available, then records it."
  @spec wait() :: :ok
  def wait, do: GenServer.call(__MODULE__, :wait, :infinity)

  @impl true
  def init(_opts) do
    {:ok, %{timestamps: []}}
  end

  @impl true
  def handle_call(:wait, from, %{timestamps: timestamps} = state) do
    limit = Application.get_env(:kusa_data, __MODULE__, []) |> Keyword.get(:limit, @default_limit)

    window =
      Application.get_env(:kusa_data, __MODULE__, [])
      |> Keyword.get(:window_ms, @default_window_ms)

    now = System.monotonic_time(:millisecond)

    case RateLimit.check(timestamps, now, limit, window) do
      :ok ->
        {:reply, :ok, %{state | timestamps: [now | timestamps]}}

      {:wait, ms} ->
        Process.send_after(self(), {:slot, from}, ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:slot, from}, state) do
    now = System.monotonic_time(:millisecond)
    GenServer.reply(from, :ok)
    {:noreply, %{state | timestamps: [now | state.timestamps]}}
  end
end
