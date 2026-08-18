# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kusa_data,
  ecto_repos: [KusaData.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :kusa_data, KusaDataWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KusaDataWeb.ErrorHTML, json: KusaDataWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: KusaData.PubSub,
  live_view: [signing_salt: "GwDZ1Lla"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Redis cache connection, set at runtime from REDIS_URL in config/runtime.exs.
# When absent the app runs without caching.
config :kusa_data, KusaData.Cache, url: nil

# PostgreSQL for first-party state. Runtime DATABASE_URL overrides these
# defaults. In development and production, leave DATABASE_URL and
# DATABASE_NAME unset to keep the Repo and stateful features disabled.
if System.get_env("DATABASE_URL") || System.get_env("DATABASE_NAME") do
  config :kusa_data, KusaData.Repo,
    username: System.get_env("DATABASE_USER", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOST", "localhost"),
    database: System.get_env("DATABASE_NAME", "kusa_data_dev"),
    pool_size: 10,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
end

config :kusa_data, :notification_email,
  smtp_host: nil,
  smtp_username: nil,
  smtp_password: nil,
  smtp_port: 587,
  from: {"KusaData", "notifications@example.invalid"}

config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  kusa_data: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  kusa_data: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
