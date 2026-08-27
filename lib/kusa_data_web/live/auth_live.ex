defmodule KusaDataWeb.AuthLive do
  @moduledoc """
  Login / register screen.

  Renders plain HTML forms (no `phx-submit`) that POST to the session and
  registration controllers (`~p"/log-in"` and `~p"/register"`). The active
  form is chosen from the `?mode=login|register` query param.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)
    {:ok, assign(socket, mode: :login)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    mode =
      case Map.get(params, "mode", "login") do
        "register" -> :register
        _ -> :login
      end

    {:noreply, assign(socket, mode: mode)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id="auth-live" class="mx-auto max-w-md py-4">
        <div class="mb-6 text-center">
          <h1 class="font-display text-2xl font-bold tracking-tight text-ink">
            Welcome to KusaData
          </h1>
          <p class="mt-1 text-sm text-muted">
            Sign in or create an account to save tournaments and track players.
          </p>
        </div>

        <%= if @current_user do %>
          <div class="mb-6 flex items-center gap-3 rounded-none border border-accent-line bg-accent-soft px-4 py-3 text-sm text-accent">
            <span class="hero-check-circle size-5 shrink-0"></span>
            <span>
              You are signed in as <span class="font-semibold"><%= @current_user.email %></span>.
            </span>
          </div>
        <% end %>

        <div class="mb-6 grid grid-cols-2 gap-2 rounded-none border border-line bg-surface p-1">
          <.link
            navigate={~p"/auth?mode=login"}
            class={[
              "rounded-none py-2 text-center text-sm font-semibold transition-colors",
              @mode == :login && "bg-surface-2 text-ink",
              @mode != :login && "text-muted hover:text-ink"
            ]}
          >
            Log in
          </.link>
          <.link
            navigate={~p"/auth?mode=register"}
            class={[
              "rounded-none py-2 text-center text-sm font-semibold transition-colors",
              @mode == :register && "bg-surface-2 text-ink",
              @mode != :register && "text-muted hover:text-ink"
            ]}
          >
            Register
          </.link>
        </div>

        <%= if @mode == :login do %>
          <div class="rounded-none border border-line bg-surface p-6">
            <h2 class="mb-4 font-display text-lg font-semibold text-ink">Log in</h2>
            <form method="post" action={~p"/log-in"}>
              <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
              <div class="flex flex-col gap-4">
                <.input
                  name="user[email]"
                  id="login-email"
                  type="email"
                  label="Email"
                  placeholder="you@example.com"
                  autocomplete="email"
                  required
                />
                <.input
                  name="user[password]"
                  id="login-password"
                  type="password"
                  label="Password"
                  placeholder="••••••••"
                  autocomplete="current-password"
                  required
                />
                <.button type="submit" variant="primary" class="w-full">Log in</.button>
              </div>
            </form>
          </div>
        <% else %>
          <div class="rounded-none border border-line bg-surface p-6">
            <h2 class="mb-4 font-display text-lg font-semibold text-ink">
              Create your account
            </h2>
            <form method="post" action={~p"/register"}>
              <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
              <div class="flex flex-col gap-4">
                <.input
                  name="user[email]"
                  id="register-email"
                  type="email"
                  label="Email"
                  placeholder="you@example.com"
                  autocomplete="email"
                  required
                />
                <.input
                  name="user[password]"
                  id="register-password"
                  type="password"
                  label="Password"
                  placeholder="At least 12 characters"
                  autocomplete="new-password"
                  required
                />
                <.button type="submit" variant="primary" class="w-full">
                  Create account
                </.button>
              </div>
            </form>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
