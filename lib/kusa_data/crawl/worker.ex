defmodule KusaData.Crawl.Worker do
  @moduledoc """
  Supervised GenServer that serializes crawl slices through a FIFO queue.
  `perform/1` enqueues a game and returns `{:ok, :enqueued}` immediately (or
  `{:error, :already_enqueued}` if it's still queued/running); the slice runs in
  a spawned-persistent task linked to the worker so only one crawl executes at
  a time app-wide — start.gg is rate-limited, and a single paced worker is
  deterministic.
  """

  use GenServer

  alias KusaData.Crawl

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc "Enqueues a crawl for `game_id`. Never blocks; returns immediately."
  @spec perform(pos_integer) :: {:ok, :enqueued} | {:error, :already_enqueued}
  def perform(game_id), do: perform(__MODULE__, game_id)

  @doc "Same as `perform/1` against a worker registered under `name`."
  @spec perform(atom | pid, pos_integer) :: {:ok, :enqueued} | {:error, :already_enqueued}
  def perform(name, game_id), do: GenServer.call(name, {:perform, game_id}, :infinity)

  @impl true
  def init(_), do: {:ok, %{queue: :queue.new(), running: nil}}

  @impl true
  def handle_call({:perform, game_id}, _from, %{running: nil} = state) do
    {:reply, {:ok, :enqueued}, spawn_slice(%{state | running: game_id}, game_id)}
  end

  def handle_call({:perform, game_id}, _from, state) do
    if game_id in queued(state) do
      {:reply, {:error, :already_enqueued}, state}
    else
      {:reply, {:ok, :enqueued}, %{state | queue: :queue.in(game_id, state.queue)}}
    end
  end

  @impl true
  def handle_info({:slice_done, game_id, _result}, %{running: game_id} = state) do
    case :queue.out(state.queue) do
      {{:value, next}, rest} ->
        {:noreply, spawn_slice(%{state | running: next, queue: rest}, next)}

      {:empty, _} ->
        {:noreply, %{state | running: nil}}
    end
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp queued(%{running: running, queue: queue}),
    do: [running | :queue.to_list(queue)] |> Enum.reject(&is_nil/1)

  defp spawn_slice(state, game_id) do
    owner = self()
    _pid = spawn_link(fn -> send(owner, {:slice_done, game_id, Crawl.run(game_id)}) end)
    state
  end

  @impl true
  def terminate(_reason, _state), do: :ok
end
