defmodule KusaDataWeb.UserSessionController do
  @moduledoc """
  Handles user login/logout via standard HTML form posts.
  """

  use KusaDataWeb, :controller

  alias KusaData.Accounts

  @doc """
  Authenticates a user from `params["user"]` (email, password).

  On success, opens a session and redirects home with a welcome flash.
  On failure, redirects back to the login form with an error flash.
  """
  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    do_create(conn, email, password)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    do_create(conn, email, password)
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> redirect(to: ~p"/auth?mode=login")
  end

  @doc """
  Logs the current user out by clearing the session.
  """
  def delete(conn, _params) do
    if Accounts.repo_configured?() do
      case get_session(conn, :user_token) do
        nil -> :ok
        token -> Accounts.delete_session(token)
      end
    end

    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  defp do_create(conn, email, password) do
    case Accounts.authenticate_by_email_password(email, password) do
      {:ok, user} ->
        conn = maybe_open_session(conn, user)

        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: ~p"/")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/auth?mode=login")
    end
  end

  defp maybe_open_session(conn, user) do
    if Accounts.repo_configured?() do
      case Accounts.create_session(user) do
        {:ok, _session, token} ->
          conn
          |> put_session(:user_token, token)
          |> configure_session(renew: true)

        {:error, _changeset} ->
          conn
      end
    else
      conn
    end
  end
end
