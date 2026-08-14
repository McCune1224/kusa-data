defmodule KusaDataWeb.HomeLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Repo, Search}

  @min_chars 2
  @limit 8

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:game, Repo.get_by(Game, key: "melee"))
     |> assign(:query, "")
     |> assign(:results, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    game = socket.assigns.game
    q = String.trim(query)

    results =
      if is_nil(game) || String.length(q) < @min_chars do
        []
      else
        Search.search_index(game, q) |> Enum.take(@limit)
      end

    {:noreply, socket |> assign(:query, q) |> assign(:results, results)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, socket |> assign(:query, "") |> assign(:results, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex max-w-3xl flex-col gap-10">
      <section class="flex flex-col items-center gap-3 text-center">
        <h1 class="text-4xl font-bold tracking-tight sm:text-5xl">
          KUSA<span class="text-accent">DATA</span>
        </h1>
        <p class="text-lg text-ink-muted">
          Melee tournament analytics — brackets, seeding, and player stats.
        </p>
      </section>

      <section id="player-search" class="flex flex-col gap-4">
        <form id="search-form" phx-change="search" role="search">
          <label for="search-input" class="sr-only">Search players</label>
          <div class="relative">
            <input
              type="search"
              id="search-input"
              name="query"
              value={@query}
              placeholder="Search players by gamer tag or prefix…"
              autocomplete="off"
              phx-debounce="300"
              data-test="search-input"
              class="w-full rounded-lg border border-line bg-card px-4 py-3 text-base text-ink placeholder:text-ink-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20"
            />
            <button
              :if={@query != ""}
              type="button"
              phx-click="clear"
              aria-label="Clear search"
              class="absolute top-1/2 right-3 -translate-y-1/2 rounded-md p-1 text-ink-muted hover:bg-paper-soft hover:text-ink"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
        </form>

        <div data-test="results" class="flex flex-col gap-2">
          <%= if @query != "" do %>
            <.empty_state
              :if={@results == []}
              title="No matches yet"
              hint="Keep typing — the tag may be new or not yet in the rankings index."
            />

            <a
              :for={result <- @results}
              href={~p"/players/#{result.player_db_id}"}
              data-test="result"
              class="flex items-center justify-between gap-3 rounded-lg border border-line bg-card p-4 transition-colors hover:border-line-strong hover:bg-paper-soft/50"
            >
              <div>
                <p class="font-semibold text-ink">
                  {if result.prefix, do: "#{result.prefix} | "}{result.gamer_tag}
                </p>
                <p class="text-sm text-ink-muted">ID #{result.user_id}</p>
              </div>
              <.badge tone={:accent}>Elo {trunc(result.elo)}</.badge>
            </a>
          <% end %>
        </div>
      </section>

      <section aria-label="Menu" class="grid gap-3 sm:grid-cols-3">
        <.card class="flex flex-col gap-2">
          <h2 class="font-semibold text-ink">Rankings</h2>
          <p class="text-sm text-ink-muted">
            The Melee leaderboard, Elo-ranked from crawled brackets.
          </p>
          <.button navigate={~p"/rankings"} variant="outline" size="sm" class="self-start">
            View rankings
          </.button>
        </.card>

        <.card class="flex flex-col gap-2">
          <h2 class="font-semibold text-ink">VS Mode</h2>
          <p class="text-sm text-ink-muted">Pick two players and compare records head-to-head.</p>
          <.button navigate={~p"/vs"} variant="outline" size="sm" class="self-start">
            Compare players
          </.button>
        </.card>

        <.card class="flex flex-col gap-2">
          <h2 class="font-semibold text-ink">Seed finder</h2>
          <p class="text-sm text-ink-muted">Paste a start.gg URL to see every entrant's seed.</p>
          <.button navigate={~p"/tournaments"} variant="outline" size="sm" class="self-start">
            Find seeds
          </.button>
        </.card>
      </section>
    </div>
    """
  end
end
