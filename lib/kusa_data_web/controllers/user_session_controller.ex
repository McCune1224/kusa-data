defmodule KusaDataWeb.UserSessionController do
  @moduledoc """
  Session lifecycle: `POST /log-in` authenticates and stores the session
  token; `DELETE /log-out` clears it.
  """

  use KusaDataWeb, :controller

  alias KusaData.Accounts

  @session_key :user_token

  def create(conn, %{"email" => email, "password" => password} = params) do
    if Accounts.repo_configured?() do
      case Accounts.authenticate_by_email_password(email, password) do
        {:ok, user} ->
          case Accounts.create_session(user) do
            {:ok, _session, token} ->
              conn
              |> put_session(@session_key, token)
              |> put_flash(:info, "Welcome back!")
              |> redirect(to: params["return_to"] || "/")

            {:error, _changeset} ->
              redirect_login_error(conn, "Could not start a session. Please try again.")
          end

        {:error, :invalid_credentials} ->
          redirect_login_error(conn, "Invalid email or password.")
      end
    else
      redirect_login_error(
        conn,
        "Accounts need a PostgreSQL database — set DATABASE_URL and restart."
      )
    end
  end

  def delete(conn, _params) do
    conn
    |> logout()
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/")
  end

  defp redirect_login_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/auth?mode=login")
  end

  defp logout(conn) do
    case get_session(conn, @session_key) do
      nil ->
        conn

      token ->
        Accounts.delete_session(token)
        delete_session(conn, @session_key)
    end
  end
end
