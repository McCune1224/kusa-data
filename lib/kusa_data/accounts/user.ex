defmodule KusaData.Accounts.User do
  @moduledoc """
  An email/password account owning bookmarks, watches, aliases, and leagues.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string, redact: true)
    field(:linked_player_id, :integer)

    field(:password, :string, virtual: true, redact: true)
    field(:reset_token_hash, :string, redact: true)
    field(:reset_sent_at, :utc_datetime_usec)
    has_many(:sessions, KusaData.Accounts.UserSession)
    has_many(:bookmarks, KusaData.Bookmarks.Bookmark)
    has_many(:watches, KusaData.Watches.Watch)
    has_many(:aliases, KusaData.PlayerLinks.PlayerAlias)
    has_many(:leagues, KusaData.Leagues.League, foreign_key: :owner_id)
    has_many(:notifications, KusaData.Watches.Notification)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Registration changeset: validates email/password and hashes the password
  with bcrypt before storage.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> update_change(:email, &String.downcase/1)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:password, min: 8, max: 72)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  @doc "Email-only changeset (used by login to fetch the record)."
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, hashed_password: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  @doc "Verifies a plaintext password against the stored hash."
  def valid_password?(%__MODULE__{hashed_password: hash}, password) when is_binary(hash) do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _), do: false
end
