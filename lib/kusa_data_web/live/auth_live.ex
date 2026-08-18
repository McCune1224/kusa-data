defmodule KusaDataWeb.AuthLive do
  use KusaDataWeb, :live_view

  alias KusaData.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :tournaments,
       mode: :login,
       return_to: "/",
       reset_token: nil,
       reset_sent: false,
       error: nil,
       form: to_form(%{"email" => "", "password" => ""}),
       reset_form: to_form(%{"email" => ""})
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    mode =
      case params["mode"] do
        "register" -> :register
        "reset" -> :reset
        "reset-confirm" -> :reset_confirm
        _ -> :login
      end

    return_to = params["return_to"] || "/"

    socket =
      if socket.assigns.current_user do
        socket
      else
        assign(socket, mode: mode, return_to: return_to, reset_token: params["token"])
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit-reset", %{"email" => email}, socket) do
    if Accounts.repo_configured?() do
      case Accounts.get_user_by_email(email) do
        nil ->
          {:noreply, assign(socket, error: nil, reset_sent: true)}

        user ->
          case Accounts.generate_reset_token(user) do
            {:ok, token} ->
              # Email delivery is wired in phase 7; until then the reset link
              # is surfaced in the server log so the flow is testable.
              require Logger
              Logger.info("password reset link: /auth?mode=reset-confirm&token=#{token}")
              {:noreply, assign(socket, error: nil, reset_sent: true)}

            {:error, _changeset} ->
              {:noreply, assign(socket, error: :reset_failed)}
          end
      end
    else
      {:noreply, assign(socket, error: :no_database)}
    end
  end

  @impl true
  def handle_event("submit-reset-confirm", %{"token" => token, "password" => password}, socket) do
    if Accounts.repo_configured?() do
      case Accounts.reset_password(token, password) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password updated — log in with your new password.")
           |> push_patch(to: "/auth?mode=login")}

        {:error, :expired_or_invalid} ->
          {:noreply, assign(socket, error: :expired_or_invalid)}
      end
    else
      {:noreply, assign(socket, error: :no_database)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="desk-grid animate-fade-up">
        <div class="mb-5 flex items-center justify-between border-y border-stone-800 py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-stone-500">
          <span><span class="mr-2 inline-block size-2 bg-lime-400"></span>Live bracket index</span>
          <span class="hidden sm:inline">Account</span>
          <span class="text-orange-300">05 — You</span>
        </div>

        <section class="mx-auto mt-10 max-w-md">
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-lime-300">
            Your tournaments, watches, and leagues
          </p>
          <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-stone-50">
            {if @mode == :register,
              do: "Join",
              else: if(@mode == :reset, do: "Reset", else: "Welcome back")}
          </h1>

          <%= if @error == :no_database do %>
            <div class="mt-6 rounded-xl border border-amber-500/40 bg-amber-500/10 px-5 py-4 text-sm text-amber-200">
              Accounts need a PostgreSQL database. Set <code class="font-mono">DATABASE_URL</code> and
              restart the app; public browsing works without it.
            </div>
          <% end %>

          <div class="mt-6 flex items-center gap-1 rounded-xl border border-stone-800 bg-stone-900/40 p-1">
            <.link patch="/auth?mode=login" class={tab_class(@mode == :login)}>Log in</.link>
            <.link patch="/auth?mode=register" class={tab_class(@mode == :register)}>Register</.link>
            <.link patch="/auth?mode=reset" class={tab_class(@mode == :reset)}>Reset</.link>
          </div>

          <div class="mt-8 rounded-xl border border-stone-800 bg-stone-900/40 p-6">
            <%= cond do %>
              <% @mode == :reset_confirm -> %>
                <.form
                  for={@form}
                  id="reset-confirm-form"
                  phx-submit="submit-reset-confirm"
                  class="space-y-4"
                >
                  <%= if @error == :expired_or_invalid do %>
                    <p class="text-sm text-rose-400">
                      That reset link is invalid or has expired — request a new one.
                    </p>
                  <% end %>
                  <input type="hidden" name="token" value={@reset_token} />
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="New password (8+ characters)"
                    autocomplete="new-password"
                    class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                  />
                  <.btn variant="primary" type="submit" class="rounded-none w-full">
                    Set new password
                  </.btn>
                </.form>
              <% @mode == :reset -> %>
                <%= if @reset_sent do %>
                  <p class="text-sm leading-relaxed text-stone-300">
                    If that email has an account, a reset link has been issued.
                    (In this build the link is logged by the server; email
                    delivery is a configurable channel.)
                  </p>
                <% else %>
                  <.form
                    for={@reset_form}
                    id="reset-form"
                    phx-submit="submit-reset"
                    class="space-y-4"
                  >
                    <.input
                      field={@reset_form[:email]}
                      type="email"
                      label="Email"
                      autocomplete="email"
                      class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                    />
                    <.btn variant="primary" type="submit" class="rounded-none w-full">
                      Send reset link
                    </.btn>
                  </.form>
                <% end %>
              <% @mode == :register -> %>
                <form
                  action={~p"/register"}
                  method="post"
                  id="register-form"
                  class="space-y-4"
                >
                  <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                  <input type="hidden" name="return_to" value={@return_to} />
                  <label class="block">
                    <span class="mb-1 block text-xs font-semibold text-stone-400">Email</span>
                    <input
                      type="email"
                      name="email"
                      autocomplete="email"
                      required
                      class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                    />
                  </label>
                  <label class="block">
                    <span class="mb-1 block text-xs font-semibold text-stone-400">Password (8+ characters)</span>
                    <input
                      type="password"
                      name="password"
                      autocomplete="new-password"
                      minlength="8"
                      required
                      class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                    />
                  </label>
                  <.btn variant="primary" type="submit" class="rounded-none w-full">
                    Create account
                  </.btn>
                </form>
              <% true -> %>
                <form action={~p"/log-in"} method="post" id="login-form" class="space-y-4">
                  <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                  <input type="hidden" name="return_to" value={@return_to} />
                  <label class="block">
                    <span class="mb-1 block text-xs font-semibold text-stone-400">Email</span>
                    <input
                      type="email"
                      name="email"
                      autocomplete="email"
                      required
                      class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                    />
                  </label>
                  <label class="block">
                    <span class="mb-1 block text-xs font-semibold text-stone-400">Password</span>
                    <input
                      type="password"
                      name="password"
                      autocomplete="current-password"
                      required
                      class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
                    />
                  </label>
                  <.btn variant="primary" type="submit" class="rounded-none w-full">
                    Log in
                  </.btn>
                </form>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp tab_class(active?) do
    base = "flex-1 px-4 py-2 text-sm font-medium transition-colors rounded-none text-center"

    if active? do
      "#{base} bg-lime-400 text-stone-950"
    else
      "#{base} text-stone-400 hover:bg-stone-800/60 hover:text-stone-100"
    end
  end
end
