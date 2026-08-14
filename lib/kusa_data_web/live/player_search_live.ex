defmodule KusaDataWeb.PlayerSearchLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Repo, Search}

  @min_chars 2

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:game, Repo.get_by(Game, key: "melee"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = String.trim(params["q"] || "")

    results =
      if q == "" or is_nil(socket.assigns.game) or String.length(q) < @min_chars do
        []
      else
        Search.search(socket.assigns.game, q)
      end

    {:noreply,
     socket
     |> assign(:query, q)
     |> assign(:results, results)
     |> assign(:page_title, "Player search")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight text-ink">Player search</h1>
        <p class="mt-1 text-ink-muted">Results are ranked: exact tag, then prefix, then substring.</p>
      </div>

      <form action="/players" method="get" role="search">
        <label for="players-search-input" class="sr-only">Search players</label>
        <input
          type="search"
          id="players-search-input"
          name="q"
          value={@query}
          placeholder="Search players by gamer tag or prefix…"
          autocomplete="off"
          class="w-full rounded-md border border-line bg-card px-4 py-3 text-base text-ink placeholder:text-ink-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20"
        />
      </form>

      <div id="search-results" class="flex flex-col gap-2">
        <%= if @query == "" do %>
          <.empty_state
            title="Search for a player"
            hint="Type a gamer tag above — e.g. Mango, Zain, Cody."
          />
        <% else %>
          <%= if @results == [] do %>
            <.empty_state
              title="No players found"
              hint="Check the spelling — the search covers crawled players plus recent tournament participants."
            />
          <% else %>
            <a
              :for={result <- @results}
              href={~p"/players/#{result.player_db_id || result.user_id}"}
              class="flex items-center justify-between gap-3 rounded-lg border border-line bg-card p-4 transition-colors hover:border-line-strong hover:bg-paper-soft/50"
            >
              <div>
                <p class="font-semibold text-ink">
                  {if result.prefix, do: "#{result.prefix} | "}{result.gamer_tag}
                </p>
                <p class="text-sm text-ink-muted">
                  ID #{result.user_id}
                  <span :if={is_nil(result.player_db_id)}>· not yet crawled</span>
                </p>
              </div>
              <.badge tone={:accent}>Elo {trunc(result.elo || 1500)}</.badge>
            </a>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
