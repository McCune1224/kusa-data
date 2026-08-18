defmodule KusaDataWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use KusaDataWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :nav, :atom, default: nil, doc: "which nav item is active: :tournaments | :players"
  attr :current_user, :any, default: nil, doc: "the signed-in user, or nil"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-950">
      <header class="border-b border-stone-800 bg-stone-950/95">
        <div class="mx-auto flex h-[4.5rem] max-w-6xl items-center justify-between px-4 sm:px-6">
          <a href="/" class="group flex items-center gap-3 text-stone-100">
            <span class="flex size-8 items-center justify-center bg-lime-400 text-sm font-black text-stone-950 transition-transform group-hover:rotate-12">K</span>
            <span class="text-[15px] font-black uppercase tracking-[0.16em]">Kusa<span class="text-lime-400">Data</span></span>
          </a>

          <nav class="hidden items-center gap-6 md:flex">
            <.nav_link to={~p"/"} active={@nav == :tournaments}>Tournaments</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings}>Rankings</.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your}>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues}>Leagues</.nav_link>
            <% end %>
          </nav>

          <div class="flex items-center gap-3">
            <button
              type="button"
              id="theme-toggle"
              data-theme-toggle
              class="rounded-none border border-stone-700/70 px-2.5 py-1.5 text-stone-400 transition-colors hover:text-stone-100"
              aria-label="Toggle light theme"
            >
              <.icon name="hero-sun" class="size-4" />
            </button>
            <%= if @current_user do %>
              <span class="hidden max-w-40 truncate text-xs text-stone-500 sm:block">
                {@current_user.email}
              </span>
              <.link
                navigate={~p"/settings"}
                class="hidden rounded-none border border-stone-700/70 px-2.5 py-1 font-mono text-xs text-stone-400 transition-colors hover:text-stone-100 sm:block"
              >
                Settings
              </.link>
              <form action={~p"/log-out"} method="post" id="logout-form">
                <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                <input type="hidden" name="_method" value="delete" />
                <button
                  type="submit"
                  class="rounded-none border border-stone-700/70 px-2.5 py-1 font-mono text-xs text-stone-400 transition-colors hover:border-rose-500/60 hover:text-rose-300"
                >
                  Log out
                </button>
              </form>
            <% else %>
              <.link
                navigate={~p"/auth?mode=login"}
                class="rounded-none border border-lime-400/40 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.14em] text-lime-300 transition-colors hover:bg-lime-400 hover:text-stone-950"
              >
                Log in
              </.link>
            <% end %>
          </div>

          <button
            type="button"
            phx-click={JS.toggle(to: "#mobile-nav")}
            aria-label="Toggle navigation"
            aria-expanded="false"
            class="-mr-2 inline-flex size-9 items-center justify-center rounded-none text-stone-400 transition-colors hover:bg-stone-800/60 hover:text-stone-100 md:hidden"
          >
            <.icon name="hero-bars-3" class="size-5" />
          </button>
        </div>

        <div id="mobile-nav" hidden class="border-t border-stone-800/70 md:hidden">
          <nav class="mx-auto flex max-w-6xl flex-col px-4 py-2 sm:px-6">
            <.nav_link to={~p"/"} active={@nav == :tournaments} mobile>Tournaments</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings} mobile>Rankings</.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your} mobile>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues} mobile>Leagues</.nav_link>
            <% end %>
          </nav>
        </div>
      </header>

      <main class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:py-12">
        {render_slot(@inner_block)}
      </main>

      <footer class="mt-16 border-t border-stone-800/70">
        <div class="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-8 text-xs text-stone-600 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <span class="font-medium tracking-tight text-stone-500">
            KUSA&nbsp;DATA · Melee tournament directory
          </span>
          <span>
            Results &amp; schedules from
            <a
              href="https://start.gg"
              target="_blank"
              rel="noopener noreferrer"
              class="transition-colors hover:text-stone-300"
            >start.gg</a>
          </span>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :to, :any, required: true
  attr :active, :boolean, default: false
  attr :mobile, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    assigns =
      assign(
        assigns,
        :classes,
        cond do
          assigns.mobile and assigns.active ->
            "border-l border-lime-400 pl-3 text-stone-100"

          assigns.mobile ->
            "border-l border-transparent pl-3 text-stone-500 hover:text-stone-200"

          assigns.active ->
            "relative border-b-2 border-lime-400 py-2 text-sm font-semibold uppercase tracking-[0.08em] text-stone-100"

          true ->
            "relative py-2 text-sm font-semibold uppercase tracking-[0.08em] text-stone-500 transition-colors hover:text-stone-200"
        end
      )

    ~H"""
    <div class={@mobile && "space-y-1 py-px"}>
      <.link navigate={@to} class={["block tracking-tight transition-colors", @classes]}>
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
