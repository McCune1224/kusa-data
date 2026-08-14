defmodule KusaDataWeb.VSLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Players, Repo, Search, Stats}

  @result_limit 5

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:game, Repo.get_by(Game, key: "melee"))
     |> assign(:panels, %{a: blank_panel(), b: blank_panel()})}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"side" => side, "query" => query}, socket) do
    q = String.trim(query)

    results =
      if q == "" or is_nil(socket.assigns.game) do
        []
      else
        Search.search_index(socket.assigns.game, q) |> Enum.take(@result_limit)
      end

    {:noreply, update_panel(socket, side, fn panel -> %{panel | query: q, results: results} end)}
  end

  @impl true
  def handle_event("select", %{"side" => side, "id" => id}, socket) do
    case Players.get(id) do
      nil ->
        {:noreply, socket}

      player ->
        stats = player_stats(socket.assigns.game, player)

        {:noreply,
         update_panel(socket, side, fn panel ->
           %{panel | selected: player, stats: stats, results: [], query: ""}
         end)}
    end
  end

  @impl true
  def handle_event("clear", %{"side" => side}, socket) do
    {:noreply, update_panel(socket, side, fn _panel -> blank_panel() end)}
  end

  defp blank_panel, do: %{query: "", results: [], selected: nil, stats: nil}

  defp update_panel(socket, side, fun) do
    panels = Map.update!(socket.assigns.panels, String.to_existing_atom(side), fun)
    assign(socket, :panels, panels)
  end

  defp player_stats(game, player) do
    sets = Players.sets(player, 50)

    %{
      rating: Players.rating(game, player),
      win_loss: Stats.win_loss(sets, player.id),
      best: Stats.best_streak(sets, player.id),
      sets: sets
    }
  end

  defp h2h(%{selected: %{id: id_a} = a, stats: %{sets: sets_a}}, %{
         selected: %{id: id_b},
         stats: %{sets: sets_b}
       }) do
    mutual = Enum.uniq_by(sets_a ++ sets_b, & &1.id)
    %{record: Stats.h2h(mutual, id_a, id_b), a: a, b: id_b}
  end

  defp h2h(_a, _b), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="vs-page" class="flex flex-col gap-8">
      <header>
        <h1 class="text-3xl font-bold tracking-tight text-ink">
          VS <span class="text-accent">MODE</span>
        </h1>
        <p class="mt-1 text-ink-muted">
          Pick two players to compare their records head-to-head.
        </p>
      </header>

      <div class="grid gap-6 md:grid-cols-[1fr_auto_1fr] md:items-stretch">
        <.panel
          :for={side <- [:a, :b]}
          side={side}
          label={side_label(side)}
          panel={@panels[side]}
          game={@game}
        />

        <div class="flex items-center justify-center">
          <span class="text-4xl font-bold text-ink-faint">VS</span>
        </div>
      </div>

      <section :if={match = h2h(@panels.a, @panels.b)} class="flex flex-col gap-3">
        <h2 class="text-xl font-semibold text-ink">Head-to-head</h2>

        <.stat_grid>
          <.stat
            label={match.a.gamer_tag}
            value={"#{match.record.wins_a}-#{match.record.wins_b}"}
            hint={"across #{match.record.total} sets"}
          />
        </.stat_grid>

        <.button navigate={~p"/players/#{match.a.id}"} variant="outline" size="sm" class="self-start">
          View {match.a.gamer_tag}
        </.button>
      </section>
    </div>
    """
  end

  attr :side, :atom, required: true
  attr :label, :string, required: true
  attr :panel, :map, required: true
  attr :game, :any, default: nil

  def panel(assigns) do
    ~H"""
    <section class="flex flex-col gap-4 rounded-lg border border-line bg-card p-5">
      <h2 class="text-lg font-semibold text-ink">{@label}</h2>

      <%= if @panel.selected do %>
        <div>
          <p class="text-2xl font-bold text-ink">
            {if @panel.selected.prefix, do: "#{@panel.selected.prefix} | "}{@panel.selected.gamer_tag}
          </p>
          <p class="mt-1 text-sm text-ink-muted">
            Elo {trunc((@panel.stats.rating && @panel.stats.rating.elo) || 0)}
          </p>
        </div>

        <.stat_grid class="grid-cols-2">
          <.stat
            label="W/L"
            value={"#{@panel.stats.win_loss.wins}-#{@panel.stats.win_loss.losses}"}
          />
          <.stat label="Best streak" value={@panel.stats.best.win} />
        </.stat_grid>

        <.button phx-click="clear" phx-value-side={@side} variant="ghost" size="sm" class="self-start">
          Change player
        </.button>
      <% else %>
        <form
          id={"vs-search-#{@side}"}
          phx-submit="search"
          class="flex gap-2"
          role="search"
        >
          <input type="hidden" name="side" value={@side} />
          <label for={"vs-input-#{@side}"} class="sr-only">Search players</label>
          <input
            type="search"
            id={"vs-input-#{@side}"}
            name="query"
            value={@panel.query}
            placeholder="Gamer tag…"
            autocomplete="off"
            class="w-full rounded-md border border-line bg-paper px-3 py-2 text-sm text-ink placeholder:text-ink-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20"
          />
          <button
            type="submit"
            class="inline-flex min-h-11 items-center rounded-md bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-strong"
          >
            Find
          </button>
        </form>

        <div id={"vs-results-#{@side}"} class="flex flex-col gap-1">
          <%= if @panel.query != "" do %>
            <%= if @panel.results == [] do %>
              <p class="text-sm text-ink-muted">No matches — try another tag.</p>
            <% else %>
              <button
                :for={result <- @panel.results}
                type="button"
                phx-click="select"
                phx-value-side={@side}
                phx-value-id={result.player_db_id}
                class="flex items-center justify-between rounded-md px-2 py-2 text-left text-sm transition-colors hover:bg-paper-soft"
              >
                <span class="font-medium text-ink">
                  {if result.prefix, do: "#{result.prefix} | "}{result.gamer_tag}
                </span>
                <span class="font-mono text-ink-muted">{trunc(result.elo)}</span>
              </button>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  defp side_label(:a), do: "1P"
  defp side_label(:b), do: "2P"
end
