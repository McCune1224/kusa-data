defmodule KusaDataWeb.UserRegistrationController do
  @moduledoc """
  Handles account registration via a standard HTML form post.
  """

  use KusaDataWeb, :controller

  alias KusaData.Accounts

  @doc """
  Registers a new user from `params["user"]` (email, password).

  On success, opens a session and redirects home with a welcome flash.
  On failure, redirects back to the registration form with an error flash.
  """
  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        case Accounts.create_session(user) do
          {:ok, _session, token} ->
            conn
            |> put_session(:user_token, token)
            |> configure_session(renew: true)
            |> put_flash(:info, "Welcome!")
            |> redirect(to: ~p"/")

          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Could not create account")
            |> redirect(to: ~p"/auth?mode=register")
        end

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create account")
        |> redirect(to: ~p"/auth?mode=register")
    end
  end
end
