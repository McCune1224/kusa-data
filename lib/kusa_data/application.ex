defmodule KusaData.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    core_children = [
      KusaDataWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:kusa_data, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KusaData.PubSub},
      KusaData.GraphQL.RateLimiter,
      KusaDataWeb.Endpoint
    ]

    children = core_children ++ repo_child() ++ redis_child() ++ poller_child()

    opts = [strategy: :one_for_one, name: KusaData.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Warm the game registry from start.gg in the background; failures are
    # non-fatal and the app runs with whatever games are already known.
    Task.start(&KusaData.Games.sync/0)

    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KusaDataWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp repo_child do
    # The repo starts whenever a database URL is configured; otherwise
    # stateful features fail closed and public routes still boot.
    if repo_configured?() do
      [KusaData.Repo]
    else
      []
    end
  end

  defp repo_configured? do
    repo_config = Application.get_env(:kusa_data, KusaData.Repo, [])

    Keyword.has_key?(repo_config, :url) or Keyword.has_key?(repo_config, :database)
  end

  defp redis_child do
    case Application.get_env(:kusa_data, KusaData.Cache, []) |> Keyword.get(:url) do
      nil ->
        []

      "" ->
        []

      url when is_binary(url) ->
        if String.starts_with?(url, "redis://") or String.starts_with?(url, "rediss://") do
          [KusaData.Redis.child_spec(url)]
        else
          require Logger

          Logger.warning(
            "REDIS_URL is set but not a redis:// URL, running without cache: #{inspect(url)}"
          )

          []
        end

      _ ->
        []
    end
  end

  defp poller_child do
    if repo_configured?(), do: [KusaData.Watches.Poller], else: []
  end
end
