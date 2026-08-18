defmodule KusaData.Accounts do
  @moduledoc """
  Email/password accounts: registration, session management, password reset
  with token expiry, and `current_user` lookup.
  """

  import Ecto.Query, warn: false

  alias KusaData.Accounts.User
  alias KusaData.Accounts.UserSession
  alias KusaData.Repo

  @reset_token_ttl 15 * 60

  @doc "Registers a new user. Returns `{:ok, user}` or `{:error, changeset}`."
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetches a user by email (for login)."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def get_user_by_email(_), do: nil

  @doc "Fetches a user by id."
  def get_user(id), do: Repo.get(User, id)

  @doc "Authenticates email/password. Returns the user or `{:error, :invalid_credentials}`."
  def authenticate_by_email_password(email, password) do
    case get_user_by_email(email) do
      nil ->
        # Constant-time-ish: hash a dummy password so timing doesn't leak
        # whether the email exists.
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if User.valid_password?(user, password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc "Creates a session for the user and returns `{:ok, session, token}`."
  def create_session(user) do
    token = UserSession.generate_token()

    case Repo.insert(UserSession.changeset(%UserSession{}, user, token)) do
      {:ok, session} -> {:ok, session, token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Looks up the user for a session token, renewing the session row."
  def get_user_by_session_token(token) do
    query =
      from(s in UserSession,
        join: u in assoc(s, :user),
        where: s.token == ^token,
        select: u,
        limit: 1
      )

    case Repo.one(query) do
      nil -> nil
      _user -> touch_session(token)
    end
  end

  @doc "Updates the session's inserted_at (signed session renewal)."
  def touch_session(token) do
    Repo.get_by(UserSession, token: token)
    |> case do
      nil ->
        nil

      session ->
        {:ok, _} =
          session
          |> Ecto.Changeset.change(inserted_at: DateTime.utc_now())
          |> Repo.update()

        Repo.get(User, session.user_id)
    end
  end

  @doc "Deletes a session by token (logout)."
  def delete_session(token) do
    Repo.get_by(UserSession, token: token) |> Repo.delete()
    :ok
  end

  @doc """
  Starts a password reset: stores a hashed token with an expiry. The plain
  token is returned once for delivery; only the hash is persisted.
  """
  def generate_reset_token(user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hash = token_hash(token)

    user
    |> Ecto.Changeset.change(reset_token_hash: hash, reset_sent_at: DateTime.utc_now())
    |> Repo.update()
    |> case do
      {:ok, _user} -> {:ok, token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Resets the password using a token. Returns `{:error, :expired_or_invalid}`
  when the token is missing, wrong, or older than `@reset_token_ttl`.
  """
  def reset_password(token, password) when is_binary(token) and is_binary(password) do
    with %User{} = user <- Repo.get_by(User, reset_token_hash: token_hash(token)),
         true <- reset_token_fresh?(user) do
      user
      |> Ecto.Changeset.change(
        hashed_password: Bcrypt.hash_pwd_salt(password),
        reset_token_hash: nil,
        reset_sent_at: nil
      )
      |> Repo.update()
    else
      _ -> {:error, :expired_or_invalid}
    end
  end

  defp token_hash(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  defp reset_token_fresh?(%User{reset_sent_at: sent_at}) do
    case sent_at do
      nil ->
        false

      sent_at ->
        DateTime.diff(DateTime.utc_now(), sent_at, :second) <= @reset_token_ttl
    end
  end

  @doc "True when a Repo is configured (stateful features available)."
  def repo_configured? do
    case Application.get_env(:kusa_data, KusaData.Repo, []) do
      config when is_list(config) ->
        Keyword.has_key?(config, :url) or Keyword.has_key?(config, :database)

      _ ->
        false
    end
  end
end
