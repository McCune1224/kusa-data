defmodule KusaData.Repo do
  @moduledoc """
  PostgreSQL repository for first-party account and product state.

  Upstream start.gg data stays in the Redis cache; this repo only owns
  users, sessions, bookmarks, watches, aliases, leagues, and notifications.
  """

  use Ecto.Repo,
    otp_app: :kusa_data,
    adapter: Ecto.Adapters.Postgres
end
