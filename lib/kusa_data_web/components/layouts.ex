defmodule KusaDataWeb.Layouts do
  @moduledoc """
  Application layouts: the HTML shell (`root.html.heex`) and the app chrome
  (nav + footer) shared by every LiveView.
  """
  use KusaDataWeb, :html
  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :nav, :atom, default: nil, doc: "which nav item is active"
  attr :current_user, :any, default: nil, doc: "the signed-in user, or nil"
  attr :page_title, :string, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-canvas text-ink">
      <header class="sticky top-0 z-40 border-b border-line bg-canvas">
        <div class="mx-auto flex h-16 max-w-7xl items-center gap-6 px-4 sm:px-6">
          <a href="/" class="group flex shrink-0 items-center gap-2.5 text-ink">
            <span class="flex size-9 items-center justify-center rounded-full bg-accent font-display text-lg font-bold text-accent-ink transition-transform group-hover:-rotate-3">
              K
            </span>
            <span class="font-display text-[17px] font-semibold tracking-tight">
              Kusa<span class="text-accent">Data</span>
            </span>
          </a>

          <nav class="hidden flex-1 items-center justify-center gap-1 md:flex">
            <.nav_link to={~p"/"} active={@nav == :tournaments}>Tournaments</.nav_link>
            <.nav_link to={~p"/atlas"} active={@nav == :atlas}>Atlas</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings}>Rankings</.nav_link>
            <.nav_link to={~p"/players/compare"} active={@nav == :players}>Players</.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your}>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues}>Leagues</.nav_link>
            <% end %>
          </nav>

          <div class="hidden shrink-0 items-center gap-2 md:flex">
            <%= if @current_user do %>
              <span class="max-w-32 truncate text-xs text-muted">{@current_user.email}</span>
              <.link
                navigate={~p"/settings"}
                class="text-sm font-medium text-muted transition-colors hover:text-ink"
              >
                Settings
              </.link>
              <form action={~p"/log-out"} method="post" id="logout-form">
                <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                <input type="hidden" name="_method" value="delete" />
                <button
                  type="submit"
                  class="text-sm font-medium text-muted transition-colors hover:text-danger"
                >
                  Log out
                </button>
              </form>
            <% else %>
              <.link
                navigate={~p"/auth?mode=login"}
                class="rounded-card bg-accent px-4 py-1.5 text-sm font-semibold text-accent-ink transition-colors hover:bg-accent-strong"
              >
                Log in
              </.link>
            <% end %>
          </div>

          <button
            type="button"
            phx-click={JS.toggle(to: "#mobile-nav")}
            aria-label="Toggle navigation"
            class="-mr-2 inline-flex size-10 items-center justify-center rounded-full border border-line text-ink transition-colors hover:border-accent-line md:hidden"
          >
            <span class="hero-bars-3 size-5"></span>
          </button>
        </div>

        <div id="mobile-nav" hidden class="fixed inset-0 z-50 flex flex-col bg-canvas md:hidden">
          <div class="flex h-16 items-center justify-between border-b border-line px-4">
            <a href="/" class="flex items-center gap-2.5">
              <span class="flex size-9 items-center justify-center rounded-full bg-accent font-display text-lg font-bold text-accent-ink">K</span>
              <span class="font-display text-[17px] font-semibold tracking-tight text-ink">Kusa<span class="text-accent">Data</span></span>
            </a>
            <button
              type="button"
              phx-click={JS.toggle(to: "#mobile-nav")}
              aria-label="Close navigation"
              class="inline-flex size-10 items-center justify-center rounded-full border border-line text-ink"
            >
              <span class="hero-x-mark size-6"></span>
            </button>
          </div>
          <nav class="flex flex-1 flex-col gap-1 overflow-y-auto px-4 py-8">
            <.nav_link to={~p"/"} active={@nav == :tournaments} mobile>Tournaments</.nav_link>
            <.nav_link to={~p"/atlas"} active={@nav == :atlas} mobile>Atlas</.nav_link>
            <.nav_link to={~p"/rankings"} active={@nav == :rankings} mobile>Rankings</.nav_link>
            <.nav_link to={~p"/players/compare"} active={@nav == :players} mobile>Players</.nav_link>
            <%= if @current_user do %>
              <.nav_link to={~p"/your-tournaments"} active={@nav == :your} mobile>Saved</.nav_link>
              <.nav_link to={~p"/leagues"} active={@nav == :leagues} mobile>Leagues</.nav_link>
            <% end %>
            <div class="mt-8 flex flex-col gap-3 border-t border-line pt-8">
              <%= if @current_user do %>
                <span class="truncate text-sm text-muted">{@current_user.email}</span>
                <.link
                  navigate={~p"/settings"}
                  class="rounded-card border border-line px-4 py-3 text-center text-sm font-semibold text-ink"
                >
                  Settings
                </.link>
                <form action={~p"/log-out"} method="post">
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                  <input type="hidden" name="_method" value="delete" />
                  <button
                    type="submit"
                    class="w-full rounded-card border border-danger/40 px-4 py-3 text-sm font-semibold text-danger"
                  >
                    Log out
                  </button>
                </form>
              <% else %>
                <.link
                  navigate={~p"/auth?mode=login"}
                  class="rounded-card bg-accent px-4 py-3 text-center text-sm font-semibold text-accent-ink"
                >
                  Log in
                </.link>
              <% end %>
            </div>
          </nav>
        </div>
      </header>

      <main class="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6 sm:py-10">
        {render_slot(@inner_block)}
      </main>

      <footer class="mt-12 border-t border-line">
        <div class="mx-auto flex max-w-7xl flex-col gap-1 px-4 py-8 text-xs text-muted sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <span class="font-medium tracking-tight">KusaData · Melee tournament directory</span>
          <span>
            Results &amp; schedules from
            <a
              href="https://start.gg"
              target="_blank"
              rel="noopener noreferrer"
              class="text-muted transition-colors hover:text-accent"
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
            "border-l-2 border-accent bg-accent-soft pl-5 text-2xl font-semibold text-ink"

          assigns.mobile ->
            "border-l-2 border-transparent pl-5 text-2xl font-semibold text-muted hover:border-accent-line hover:text-ink"

          assigns.active ->
            "border-b-2 border-accent pb-1 text-sm font-semibold text-ink"

          true ->
            "border-b-2 border-transparent pb-1 text-sm font-medium text-muted transition-colors hover:border-accent-line hover:text-ink"
        end
      )

    ~H"""
    <div class={@mobile && "py-1"}>
      <.link navigate={@to} class={["block leading-none transition-colors", @classes]}>
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed inset-x-0 top-4 z-[60] flex flex-col items-center gap-2 px-4"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
