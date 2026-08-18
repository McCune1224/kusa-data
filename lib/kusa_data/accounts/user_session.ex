defmodule KusaData.Accounts.UserSession do
  @moduledoc """
  A signed, renewable session cookie token bound to a user.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "user_sessions" do
    field(:token, :string)
    belongs_to(:user, KusaData.Accounts.User)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc "Builds a session row for a freshly minted random token."
  def changeset(session, user, token) do
    session
    |> cast(%{token: token, user_id: user.id}, [:token, :user_id])
    |> validate_required([:token, :user_id])
  end

  @doc "Generates a URL-safe session token."
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
