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

    children = core_children ++ redis_child()

    opts = [strategy: :one_for_one, name: KusaData.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KusaDataWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp redis_child do
    case Application.get_env(:kusa_data, KusaData.Cache, []) |> Keyword.get(:url) do
      nil -> []
      url -> [KusaData.Redis.child_spec(url)]
    end
  end
end
