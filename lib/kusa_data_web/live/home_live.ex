defmodule KusaDataWeb.HomeLive do
  @moduledoc """
  Landing page: upcoming Melee tournaments, recent results, and search.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, section: :home, query: "", upcoming: [], recent: [], results: [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    q = Map.get(params, "q", "")

    socket =
      if String.trim(q) != "" do
        results = safe_browse(%{mode: :search, q: q})["tournaments"] || []
        assign(socket, section: :search, query: q, results: results)
      else
        upcoming = safe_browse(%{mode: :upcoming})["tournaments"] || []
        recent = safe_browse(%{mode: :past, results_only: true})["tournaments"] || []
        assign(socket, section: :home, query: "", upcoming: upcoming, recent: recent)
      end

    {:noreply, socket}
  end

  defp safe_browse(query) do
    case KusaData.Tournaments.browse(query) do
      {:ok, page, _cache} -> page
      {:error, _reason} -> %{"tournaments" => []}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <section class="desk-grid relative overflow-hidden rounded-card border border-line bg-surface px-6 py-14 sm:px-10 sm:py-20">
        <div class="relative mx-auto max-w-2xl text-center">
          <span class="inline-flex items-center gap-2 rounded-pill border border-accent-line bg-accent-soft px-3 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-accent">
            <span class="hero-bolt size-3.5"></span> Melee tournament directory
          </span>
          <h1 class="mt-5 font-display text-4xl font-bold tracking-tight text-ink sm:text-5xl">
            Find your next <span class="text-accent">Melee</span> bracket
          </h1>
          <p class="mx-auto mt-4 max-w-xl text-base text-muted">
            Browse upcoming tournaments, dig into seeds and results, and track players across the scene — all from start.gg.
          </p>
          <form action={~p"/"} method="get" class="mx-auto mt-7 flex max-w-md items-center gap-2">
            <input
              type="search"
              name="q"
              value={@query}
              placeholder="Search by name, city, or venue…"
              aria-label="Search tournaments"
              class="w-full rounded-pill border border-line bg-canvas px-4 py-2.5 text-sm text-ink placeholder:text-faint focus:border-accent-line focus:outline-none focus:ring-2 focus:ring-accent/20"
            />
            <.button type="submit" class="shrink-0 !rounded-pill">Search</.button>
          </form>
        </div>
      </section>

      <%= if @section == :search do %>
        <section class="mt-10">
          <h2 class="font-display text-xl font-semibold text-ink">
            Results for “{@query}”
          </h2>
          <%= if Enum.empty?(@results) do %>
            <.empty
              class="mt-6"
              icon="hero-magnifying-glass"
              title="No tournaments found"
              description="Try a different name, city, or venue."
            />
          <% else %>
            <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for tournament <- @results do %>
                <.tournament_card tournament={tournament} />
              <% end %>
            </div>
          <% end %>
        </section>
      <% else %>
        <section class="mt-10">
          <div class="flex items-end justify-between">
            <h2 class="font-display text-xl font-semibold text-ink">Upcoming tournaments</h2>
            <.link navigate={~p"/regions"} class="text-sm font-medium text-accent hover:underline">Browse by region</.link>
          </div>
          <%= if Enum.empty?(@upcoming) do %>
            <.empty
              class="mt-6"
              icon="hero-calendar"
              title="No upcoming tournaments"
              description="Check back soon — the scene never sleeps for long."
            />
          <% else %>
            <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for tournament <- @upcoming do %>
                <.tournament_card tournament={tournament} />
              <% end %>
            </div>
          <% end %>
        </section>

        <section class="mt-12">
          <h2 class="font-display text-xl font-semibold text-ink">Recent results</h2>
          <%= if Enum.empty?(@recent) do %>
            <.empty
              class="mt-6"
              icon="hero-trophy"
              title="No recent results yet"
            />
          <% else %>
            <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for tournament <- @recent do %>
                <.tournament_card tournament={tournament} />
              <% end %>
            </div>
          <% end %>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
