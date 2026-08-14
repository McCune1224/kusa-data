defmodule KusaData.Repo do
  use Ecto.Repo,
    otp_app: :kusa_data,
    adapter: Ecto.Adapters.Postgres
end
