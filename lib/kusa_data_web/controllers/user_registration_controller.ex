defmodule KusaDataWeb.UserRegistrationController do
  @moduledoc """
  `POST /register` creates an account and starts a session.
  """

  use KusaDataWeb, :controller

  alias KusaData.Accounts

  @session_key :user_token

  def create(conn, %{"email" => email, "password" => password} = params) do
    if Accounts.repo_configured?() do
      case Accounts.register_user(%{email: email, password: password}) do
        {:ok, user} ->
          case Accounts.create_session(user) do
            {:ok, _session, token} ->
              conn
              |> put_session(@session_key, token)
              |> put_flash(:info, "Account created — welcome!")
              |> redirect(to: params["return_to"] || "/")

            {:error, _changeset} ->
              redirect_register_error(conn, "Could not start a session. Please try again.")
          end

        {:error, changeset} ->
          message =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
            |> Enum.map(fn {field, errors} -> "#{field} #{Enum.join(errors, ", ")}" end)
            |> Enum.join("; ")

          redirect_register_error(conn, message)
      end
    else
      redirect_register_error(
        conn,
        "Accounts need a PostgreSQL database — set DATABASE_URL and restart."
      )
    end
  end

  defp redirect_register_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/auth?mode=register")
  end
end
