import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kusa_data, KusaDataWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "w0gMc9hI2NmJAB0Aq+bacJKKto0e7pfeLw25aHwEv6Fyw6iZEYYZhJtLU8s4FnCK",
  server: false

# Test doubles for network access: requests are routed to an in-memory fake.
config :kusa_data, KusaData.GraphQL.Client,
  token: "test-token",
  transport: KusaData.Test.FakeTransport

# The limiter's default window never throttles the test suite.
config :kusa_data, KusaData.GraphQL.RateLimiter, limit: 100_000

# In-memory Redis fake.
config :kusa_data, KusaData.Cache, command: {KusaData.Test.FakeRedis, :command}

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
