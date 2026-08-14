defmodule KusaDataWeb.RankingsLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Rankings, Repo}

  @impl true
  def mount(_params, _session, socket) do
    game = Repo.get_by(Game, key: "melee")

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:query, "")
     |> assign(:players, leaderboard(game))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"query" => query}, socket) do
    q = String.trim(query)

    players =
      if q == "" do
        leaderboard(socket.assigns.game)
      else
        Rankings.search(socket.assigns.game, q, 100)
      end

    {:noreply, socket |> assign(:query, q) |> assign(:players, players)}
  end

  defp leaderboard(nil), do: []
  defp leaderboard(game), do: Rankings.top(game, 100)

  defp top_elo([]), do: "—"
  defp top_elo([%{elo: elo} | _]), do: trunc(elo)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-ink">Rankings</h1>
          <p class="mt-1 text-ink-muted">
            The Melee leaderboard — Elo computed from crawled bracket sets, 90-day window.
          </p>
        </div>

        <form id="rankings-form" phx-change="filter" role="search">
          <label for="rankings-filter" class="sr-only">Filter the leaderboard</label>
          <input
            type="search"
            id="rankings-filter"
            name="query"
            value={@query}
            placeholder="Filter by tag…"
            autocomplete="off"
            phx-debounce="300"
            class="w-full rounded-md border border-line bg-card px-3 py-2 text-sm text-ink placeholder:text-ink-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20 sm:w-64"
          />
        </form>
      </div>

      <.stat_grid>
        <.stat label="Players ranked" value={length(@players)} />
        <.stat label="Top Elo" value={top_elo(@players)} />
      </.stat_grid>

      <div id="rankings-results">
        <%= if @players == [] do %>
          <.empty_state
            title="No players match"
            hint="Try a different tag — the index covers players from crawled brackets."
          />
        <% else %>
          <.table id="leaderboard-rows">
            <:head>
              <th class="p-3 text-left">Rank</th>
              <th class="p-3 text-left">Player</th>
              <th class="p-3 text-right">Elo</th>
              <th class="p-3 text-right">W/L</th>
              <th class="p-3 text-right">Sets</th>
            </:head>

            <tr :for={{player, rank} <- Enum.with_index(@players, 1)}>
              <td class="p-3 text-ink-faint">{rank}</td>
              <td class="p-3">
                <.link
                  href={~p"/players/#{player.player_db_id}"}
                  class="font-medium text-ink hover:text-accent"
                >
                  {if player.prefix, do: "#{player.prefix} | "}{player.gamer_tag}
                </.link>
              </td>
              <td class="p-3 text-right font-mono">{trunc(player.elo)}</td>
              <td class="p-3 text-right font-mono">
                {player.wins}-{player.losses}
              </td>
              <td class="p-3 text-right font-mono">{player.sets}</td>
            </tr>
          </.table>
        <% end %>
      </div>
    </div>
    """
  end
end
