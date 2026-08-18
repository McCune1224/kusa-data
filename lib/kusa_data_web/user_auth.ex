defmodule KusaDataWeb.UserAuth do
  @moduledoc """
  Session-based authentication plugs and LiveView mounts.

  The session cookie stores a `user_token`; `mount_current_user` resolves it
  to the signed-in user, `require_authenticated_user` redirects anonymous
  visitors to the login page (preserving the intended destination), and
  `redirect_if_user_is_authenticated` keeps auth pages away from signed-in
  users.
  """

  import Plug.Conn

  alias KusaData.Accounts

  @session_key :user_token

  @doc "Plug: fetches the current user from the session token."
  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil -> assign(conn, :current_user, nil)
      token -> assign(conn, :current_user, Accounts.get_user_by_session_token(token))
    end
  end

  @doc "LiveView mounts: current-user assignment, auth redirects."
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_user, user_from_session(session))}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    if user_from_session(session) do
      {:cont, Phoenix.Component.assign(socket, :current_user, user_from_session(session))}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: login_path(socket))}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    if user_from_session(session) do
      {:halt, Phoenix.LiveView.push_navigate(socket, to: "/")}
    else
      {:cont, socket}
    end
  end

  defp user_from_session(%{"user_token" => token}) do
    Accounts.get_user_by_session_token(token)
  end

  defp user_from_session(_session), do: nil

  defp login_path(socket) do
    case return_path(socket) do
      "/" -> "/auth?mode=login"
      path -> "/auth?mode=login&return_to=#{URI.encode_www_form(path)}"
    end
  end

  defp return_path(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :uri) do
      %URI{path: path, query: query} when is_binary(path) ->
        path <> if(query, do: "?" <> query, else: "")

      _ ->
        "/"
    end
  end
end
