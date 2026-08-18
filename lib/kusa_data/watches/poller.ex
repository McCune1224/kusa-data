defmodule KusaData.Watches.Poller do
  @moduledoc """
  Supervised periodic watch poller. The shared GraphQL limiter remains the
  final gate before upstream requests; one tick is bounded to avoid bursts.
  """
  use GenServer

  @default_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    if KusaData.Accounts.repo_configured?(), do: schedule(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:poll, state) do
    if KusaData.Accounts.repo_configured?() do
      KusaData.Watches.poll_due()
      KusaData.Watches.deliver_pending()
    end

    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(interval), do: Process.send_after(self(), :poll, interval)
end
