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
    <div class="min-h-screen bg-[#08070b] text-[#f5f3ff]">
      <header class="sticky top-0 z-40 border-b border-[rgba(255,255,255,0.08)] bg-[rgba(8,7,11,0.8)] backdrop-blur-xl supports-[backdrop-filter]:bg-[rgba(8,7,11,0.8)]">
        <div class="mx-auto flex h-[4.5rem] max-w-6xl items-center justify-between px-4 sm:px-6">
          <a href="/" class="group flex items-center gap-3 text-[#f5f3ff]">
            <span class="flex size-8 items-center justify-center bg-[#a3e635] text-sm font-black text-[#08070b] transition-transform group-hover:rotate-12">K</span>
            <span class="text-[15px] font-black uppercase tracking-[0.16em]">Kusa<span class="text-[#a3e635]">Data</span></span>
          </a>

          <nav class="hidden items-center gap-6 md:flex">
            <.nav_link to={~p"/"} active={@nav == :tournaments}>Tournaments</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings}>Rankings</.nav_link>
            <.nav_link to={~p"/atlas"} active={@nav == :atlas}>
              <span class="inline-flex items-center gap-1.5">
                Atlas
                <span class="rounded-full bg-[#a3e635] px-1.5 py-0.5 text-[9px] font-bold leading-none tracking-widest text-[#08070b]">NEW</span>
              </span>
            </.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your}>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues}>Leagues</.nav_link>
            <% end %>
          </nav>

          <div class="flex items-center gap-3">
            <button
              type="button"
              class="hidden items-center gap-2 rounded-full border border-[rgba(255,255,255,0.08)] bg-[rgba(255,255,255,0.04)] px-3 py-1.5 text-xs text-[#9a95b0] transition-colors hover:border-[rgba(255,255,255,0.14)] hover:text-[#f5f3ff] md:inline-flex"
              aria-label="Search"
            >
              <span class="font-mono text-[11px] leading-none">⌘K</span>
              <span>Search</span>
            </button>
            <button
              type="button"
              id="theme-toggle"
              data-theme-toggle
              class="rounded-full border border-[rgba(255,255,255,0.08)] px-2.5 py-1.5 text-[#9a95b0] transition-colors hover:border-[rgba(255,255,255,0.14)] hover:text-[#f5f3ff]"
              aria-label="Toggle light theme"
            >
              <.icon name="hero-sun" class="size-4" />
            </button>
            <%= if @current_user do %>
              <span class="hidden max-w-40 truncate text-xs text-[#9a95b0] sm:block">
                {@current_user.email}
              </span>
              <.link
                navigate={~p"/settings"}
                class="hidden rounded-full border border-[rgba(255,255,255,0.08)] px-2.5 py-1 font-mono text-xs text-[#9a95b0] transition-colors hover:border-[rgba(255,255,255,0.14)] hover:text-[#f5f3ff] sm:block"
              >
                Settings
              </.link>
              <form action={~p"/log-out"} method="post" id="logout-form">
                <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                <input type="hidden" name="_method" value="delete" />
                <button
                  type="submit"
                  class="rounded-full border border-[rgba(255,255,255,0.08)] px-2.5 py-1 font-mono text-xs text-[#9a95b0] transition-colors hover:border-rose-500/60 hover:text-rose-300"
                >
                  Log out
                </button>
              </form>
            <% else %>
              <.link
                navigate={~p"/auth?mode=login"}
                class="rounded-full border border-[#a3e635]/40 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.14em] text-[#a3e635] transition-colors hover:bg-[#a3e635] hover:text-[#08070b]"
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
            class="-mr-2 inline-flex size-9 items-center justify-center rounded-full text-[#9a95b0] transition-colors hover:bg-[rgba(255,255,255,0.06)] hover:text-[#f5f3ff] md:hidden"
          >
            <.icon name="hero-bars-3" class="size-5" />
          </button>
        </div>

        <div id="mobile-nav" hidden class="border-t border-[rgba(255,255,255,0.08)] md:hidden">
          <nav class="mx-auto flex max-w-6xl flex-col px-4 py-2 sm:px-6">
            <.nav_link to={~p"/"} active={@nav == :tournaments} mobile>Tournaments</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings} mobile>Rankings</.nav_link>
            <.nav_link to={~p"/atlas"} active={@nav == :atlas} mobile>
              <span class="inline-flex items-center gap-1.5">
                Atlas
                <span class="rounded-full bg-[#a3e635] px-1.5 py-0.5 text-[9px] font-bold leading-none tracking-widest text-[#08070b]">NEW</span>
              </span>
            </.nav_link>
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

      <footer class="mt-16 border-t border-[rgba(255,255,255,0.08)]">
        <div class="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-8 text-xs text-[#9a95b0] sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <span class="font-medium tracking-tight text-[#9a95b0]">
            KUSA&nbsp;DATA · Melee tournament directory
          </span>
          <span>
            Results &amp; schedules from
            <a
              href="https://start.gg"
              target="_blank"
              rel="noopener noreferrer"
              class="transition-colors hover:text-[#f5f3ff]"
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
            "border-l-2 border-[#a3e635] pl-3 text-[#f5f3ff]"

          assigns.mobile ->
            "border-l border-transparent pl-3 text-[#9a95b0] hover:text-[#f5f3ff]"

          assigns.active ->
            "relative border-b-2 border-[#a3e635] py-2 text-sm font-semibold uppercase tracking-[0.08em] text-[#f5f3ff] after:absolute after:bottom-[-2px] after:left-0 after:h-[2px] after:w-full after:bg-[#a3e635] after:content-['']"

          true ->
            "relative py-2 text-sm font-semibold uppercase tracking-[0.08em] text-[#9a95b0] transition-colors hover:text-[#f5f3ff]"
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
