defmodule KusaDataWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use KusaDataWeb, :html
  embed_templates "layouts/*"
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :nav, :atom, default: nil, doc: "which nav item is active: :tournaments | :players"
  attr :current_user, :any, default: nil, doc: "the signed-in user, or nil"
  slot :inner_block, required: true
  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#08070b] text-[#f5f3ff]">
      <header class="sticky top-0 z-40 bg-[#08070b]">
        <div class="h-[3px] w-full bg-[#ffcc00]"></div>
        <div class="border-y-2 border-[#1e1e1e] bg-[#08070b]">
          <div class="mx-auto flex h-[3.75rem] max-w-7xl items-center justify-between gap-4 px-4 sm:px-6">
            <a href="/" class="group flex items-center gap-3 text-[#f5f3ff]">
              <span class="relative flex size-10 items-center justify-center bg-[#ffcc00] text-[16px] font-black leading-none text-[#08070b] border-2 border-[#08070b] transition-transform group-hover:rotate-1">
                K
                <span class="absolute -right-1.5 -top-1.5 size-[10px] border-2 border-[#08070b] bg-[#ffcc00]"></span>
              </span>
              <span class="hidden text-[15px] font-black uppercase tracking-[0.16em] sm:block">Kusa<span class="text-[#ffcc00]">Data</span></span>
            </a>

            <nav class="hidden items-center gap-1 md:flex">
              <.nav_link to={~p"/"} active={@nav == :tournaments}>Tournaments</.nav_link>
              <.nav_link to={~p"/atlas"} active={@nav == :atlas}>
                <span class="inline-flex items-center gap-1.5">
                  Atlas
                  <span class="rounded-full bg-[#ffcc00] px-1.5 py-0.5 text-[9px] font-black leading-none tracking-[0.14em] text-[#08070b]">NEW</span>
                </span>
              </.nav_link>
              <.nav_link to={~p"/rankings"} active={@nav == :rankings}>Rankings</.nav_link>
              <.nav_link to={~p"/players/compare"} active={@nav == :players}>Players</.nav_link>
              <%= if @current_user do %>
                <.nav_link to={~p"/your-tournaments"} active={@nav == :your}>Saved</.nav_link>
                <.nav_link to={~p"/leagues"} active={@nav == :leagues}>Leagues</.nav_link>
              <% end %>
            </nav>

            <div class="hidden items-center gap-2 md:flex">
              <button
                type="button"
                class="hidden items-center gap-2 border-2 border-[rgba(255,255,255,0.12)] bg-[rgba(255,255,255,0.04)] px-3 py-1.5 text-xs font-bold uppercase tracking-[0.08em] text-[#9a95b0] transition-colors hover:border-[rgba(255,255,255,0.22)] hover:text-[#f5f3ff] lg:inline-flex"
                aria-label="Search"
              >
                <span class="rounded border border-[rgba(255,255,255,0.12)] bg-[#1a1a1a] px-1.5 py-0.5 font-mono text-[10px] leading-none">⌘K</span>
                <span>Search</span>
              </button>
              <button
                type="button"
                id="theme-toggle"
                data-theme-toggle
                class="inline-flex items-center gap-1.5 border-2 border-[#ffcc00]/40 bg-[#1a1a1a] px-3 py-1.5 text-xs font-black uppercase tracking-[0.12em] text-[#ffcc00] transition-colors hover:bg-[#ffcc00] hover:text-[#08070b]"
                aria-label="Toggle theme"
              >
                <.icon name="hero-sun" class="size-4" />
                <span class="hidden xl:inline">Theme</span>
              </button>
              <%= if @current_user do %>
                <span class="hidden max-w-32 truncate text-xs font-medium text-[#9a95b0] xl:block">
                  {@current_user.email}
                </span>
                <.link
                  navigate={~p"/settings"}
                  class="hidden border-2 border-[rgba(255,255,255,0.12)] px-3 py-1.5 text-xs font-bold uppercase tracking-[0.08em] text-[#9a95b0] transition-colors hover:border-[rgba(255,255,255,0.22)] hover:text-[#f5f3ff] sm:block"
                >
                  Settings
                </.link>
                <form action={~p"/log-out"} method="post" id="logout-form">
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                  <input type="hidden" name="_method" value="delete" />
                  <button
                    type="submit"
                    class="border-2 border-[rgba(255,255,255,0.12)] px-3 py-1.5 text-xs font-bold uppercase tracking-[0.08em] text-[#9a95b0] transition-colors hover:border-rose-500/60 hover:text-rose-300"
                  >
                    Log out
                  </button>
                </form>
              <% else %>
                <.link
                  navigate={~p"/auth?mode=login"}
                  class="border-2 border-[#ffcc00] bg-[#ffcc00] px-4 py-1.5 text-xs font-black uppercase tracking-[0.12em] text-[#08070b] transition-colors hover:bg-[#ffd60a]"
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
              class="-mr-2 inline-flex size-10 items-center justify-center border-2 border-[rgba(255,255,255,0.12)] bg-[#121116] text-[#f5f3ff] transition-colors hover:border-[#ffcc00]/40 md:hidden"
            >
              <.icon name="hero-bars-3" class="size-5" />
            </button>
          </div>
        </div>

        <div id="mobile-nav" hidden class="fixed inset-0 z-50 flex flex-col bg-[#08070b] md:hidden">
          <div class="h-[3px] w-full bg-[#ffcc00]"></div>
          <div class="flex h-[3.75rem] items-center justify-between border-b-2 border-[#1e1e1e] px-4">
            <a href="/" class="flex items-center gap-3">
              <span class="relative flex size-10 items-center justify-center bg-[#ffcc00] text-[16px] font-black text-[#08070b] border-2 border-[#08070b]">
                K
                <span class="absolute -right-1.5 -top-1.5 size-[10px] border-2 border-[#08070b] bg-[#ffcc00]"></span>
              </span>
              <span class="text-[15px] font-black uppercase tracking-[0.16em] text-[#f5f3ff]">Kusa<span class="text-[#ffcc00]">Data</span></span>
            </a>
            <button
              type="button"
              phx-click={JS.toggle(to: "#mobile-nav")}
              aria-label="Close navigation"
              class="inline-flex size-10 items-center justify-center border-2 border-[rgba(255,255,255,0.12)] text-[#f5f3ff]"
            >
              <.icon name="hero-x-mark" class="size-6" />
            </button>
          </div>
          <nav class="flex flex-1 flex-col gap-1 overflow-y-auto px-4 py-8">
            <.nav_link to={~p"/"} active={@nav == :tournaments} mobile>Tournaments</.nav_link>
            <.nav_link to={~p"/atlas"} active={@nav == :atlas} mobile>
              <span class="inline-flex items-center gap-3">
                Atlas
                <span class="rounded-full bg-[#ffcc00] px-2 py-1 text-[10px] font-black leading-none tracking-[0.14em] text-[#08070b]">NEW</span>
              </span>
            </.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings} mobile>Rankings</.nav_link>
            <.nav_link to={~p"/players/compare"} active={@nav == :players} mobile>Players</.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your} mobile>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues} mobile>Leagues</.nav_link>
            <% end %>
            <div class="mt-8 flex flex-col gap-3 border-t-2 border-[#1e1e1e] pt-8">
              <button
                type="button"
                class="flex items-center justify-between border-2 border-[rgba(255,255,255,0.12)] bg-[rgba(255,255,255,0.04)] px-4 py-3 text-sm font-bold uppercase tracking-[0.08em] text-[#9a95b0]"
                aria-label="Search"
              >
                <span>Search</span>
                <span class="rounded border border-[rgba(255,255,255,0.12)] bg-[#1a1a1a] px-2 py-1 font-mono text-xs">⌘K</span>
              </button>
              <button
                type="button"
                data-theme-toggle
                class="flex items-center justify-center gap-2 border-2 border-[#ffcc00]/40 bg-[#1a1a1a] px-4 py-3 text-sm font-black uppercase tracking-[0.12em] text-[#ffcc00]"
                aria-label="Toggle theme"
              >
                <.icon name="hero-sun" class="size-5" />
                Toggle Theme
              </button>
              <%= if @current_user do %>
                <div class="flex flex-col gap-3">
                  <span class="truncate text-sm text-[#9a95b0]">{@current_user.email}</span>
                  <.link navigate={~p"/settings"} class="border-2 border-[rgba(255,255,255,0.12)] px-4 py-3 text-center text-sm font-bold uppercase tracking-[0.08em] text-[#f5f3ff]">Settings</.link>
                  <form action={~p"/log-out"} method="post">
                    <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                    <input type="hidden" name="_method" value="delete" />
                    <button type="submit" class="w-full border-2 border-rose-500/40 px-4 py-3 text-sm font-bold uppercase tracking-[0.08em] text-rose-300">Log out</button>
                  </form>
                </div>
              <% else %>
                <.link navigate={~p"/auth?mode=login"} class="border-2 border-[#ffcc00] bg-[#ffcc00] px-4 py-3 text-center text-sm font-black uppercase tracking-[0.12em] text-[#08070b]">Log in</.link>
              <% end %>
            </div>
          </nav>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:py-12">
        {render_slot(@inner_block)}
      </main>

      <footer class="mt-16 border-t-2 border-[#1e1e1e]">
        <div class="mx-auto flex max-w-7xl flex-col gap-1 px-4 py-8 text-xs text-[#9a95b0] sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <span class="font-medium tracking-tight text-[#9a95b0]">
            KUSA&nbsp;DATA · Melee tournament directory
          </span>
          <span>
            Results &amp; schedules from
            <a href="https://start.gg" target="_blank" rel="noopener noreferrer" class="transition-colors hover:text-[#f5f3ff]">start.gg</a>
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
            "border-l-[4px] border-[#ffcc00] bg-[rgba(255,204,0,0.08)] pl-6 text-3xl font-black uppercase tracking-[0.08em] text-[#f5f3ff]"

          assigns.mobile ->
            "border-l-[4px] border-transparent pl-6 text-3xl font-black uppercase tracking-[0.08em] text-[#9a95b0] hover:border-[rgba(255,255,255,0.12)] hover:text-[#f5f3ff]"

          assigns.active ->
            "border-b-[3px] border-[#ffcc00] pb-[2px] text-[13px] font-black uppercase tracking-[0.10em] text-[#f5f3ff]"

          true ->
            "border-b-[3px] border-transparent pb-[2px] text-[13px] font-black uppercase tracking-[0.10em] text-[#9a95b0] transition-colors hover:border-[rgba(255,204,0,0.35)] hover:text-[#f5f3ff]"
        end
      )

    ~H"""
    <div class={@mobile && "py-2"}>
      <.link navigate={@to} class={["block leading-none transition-colors", @classes, !@mobile && "py-3", @mobile && "py-3"]}>
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

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
