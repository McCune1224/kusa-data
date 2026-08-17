defmodule KusaDataWeb.PlayerLive do
  use KusaDataWeb, :live_view

  alias KusaData.Stats

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, stats: nil, error: nil, loading: true, player_id: nil, nav: :tournaments)}
  end

  @impl true
  def handle_params(%{"id" => player_id}, _uri, socket) do
    socket = assign(socket, player_id: player_id, stats: nil, error: nil, loading: true)
    socket = spawn_stats_load(socket, player_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:stats_loaded, ref, result}, %{assigns: %{stats_ref: ref}} = socket) do
    case result do
      {:ok, stats, _status} ->
        {:noreply, assign(socket, stats: stats, error: nil, loading: false, stats_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, stats: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:stats_loaded, _ref, _result}, socket) do
    {:noreply, socket}
  end

  defp spawn_stats_load(socket, player_id) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:stats_loaded, ref, Stats.for_player(player_id)})
    end)

    assign(socket, stats_ref: ref)
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    player_id = socket.assigns.player_id || socket.assigns.stats["player_id"]
    Stats.clear_cache(player_id)

    socket = assign(socket, stats: nil, loading: true)
    {:noreply, spawn_stats_load(socket, player_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav}>
      <div>
        <%= cond do %>
          <% is_nil(@stats) and @loading -> %>
            <div class="space-y-4">
              <div>
                <div class="skeleton h-3 w-32 rounded-md"></div>
                <div class="mt-5 flex items-center gap-4">
                  <div class="skeleton size-12 rounded-full"></div>
                  <div class="space-y-2.5">
                    <div class="skeleton h-8 w-56 rounded-md"></div>
                    <div class="skeleton h-4 w-72 rounded-md"></div>
                  </div>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <.skeleton :for={_ <- 1..4} class="h-24 rounded-xl" />
              </div>
            </div>
          <% is_nil(@stats) -> %>
            <.empty_state icon="hero-exclamation-triangle" title="Couldn't load this player">
              <:body>
                <%= if @error == :not_found do %>
                  No player with that id was found in any recent tournament roster.
                <% else %>
                  The start.gg API may be unhappy right now — try again in a moment.
                <% end %>
              </:body>
              <:action>
                <.btn variant="primary" navigate={~p"/"}>Back to browsing</.btn>
              </:action>
            </.empty_state>
          <% true -> %>
            <div class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              Player analytics
            </div>
            <div class="mt-3">
              <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
                Back
              </.btn>
            </div>

            <div class="mt-5 flex flex-wrap items-center justify-between gap-4">
              <div class="flex min-w-0 items-center gap-4">
                <.avatar name={@stats["gamer_tag"]} class="size-12 text-base" />
                <div class="min-w-0">
                  <h1 class="truncate text-3xl font-semibold tracking-tight text-stone-50">
                    {@stats["gamer_tag"]}
                  </h1>
                  <div class="mt-1 font-mono text-[13px] text-stone-400">
                    player {@stats["player_id"]} · {set_history_label(@stats)}
                  </div>
                </div>
              </div>
              <.btn
                variant="ghost"
                size="sm"
                phx-click="refresh"
                phx-disable-with="Refreshing…"
                icon="hero-arrow-path"
              >
                Refresh
              </.btn>
            </div>

            <div class="mt-8 grid grid-cols-2 gap-3 lg:grid-cols-4">
              <.stat label="Wins" value={@stats["wins"]} value_class="text-emerald-400" />
              <.stat label="Losses" value={@stats["losses"]} value_class="text-rose-400" />
              <.stat label="Win rate" value={percent(@stats["win_rate"])} />
              <.stat
                label="Sets analyzed"
                value={"last #{@stats["completed_sets"]}"}
                sub={"of #{@stats["sets_seen"]} fetched"}
              />
            </div>

            <div class="mt-4 grid gap-4 lg:grid-cols-2">
              <.card class="p-5">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Character usage
                  </h2>
                  <span class="text-sm text-stone-500">(recent sets)</span>
                </div>
                <div id="characters" class="mt-5 space-y-3">
                  <div class="hidden only:block text-sm text-stone-500">No character data yet.</div>
                  <div :for={char <- @stats["characters"]} class="flex items-center gap-3">
                    <span class="w-28 shrink-0 truncate text-[15px] font-medium text-stone-300">
                      {char["name"]}
                    </span>
                    <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-stone-800">
                      <div
                        class="h-full rounded-full bg-lime-400 transition-all duration-300"
                        style={"width: #{char_pct(char, @stats)}%"}
                      >
                      </div>
                    </div>
                    <span class="w-14 shrink-0 text-right font-mono text-[13px] text-stone-400">
                      {char["games"]} game{plural(char["games"])}
                    </span>
                  </div>
                </div>
              </.card>

              <.card class="p-5">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Head-to-head
                  </h2>
                  <span class="text-sm text-stone-500">(top opponents)</span>
                </div>
                <div class="mt-5 space-y-1">
                  <div class="hidden only:block text-sm text-stone-500">No opponents yet.</div>
                  <div
                    :for={opponent <- @stats["opponents"]}
                    class="flex items-center justify-between gap-3 rounded-md px-3.5 py-3 transition-colors hover:bg-stone-900/60"
                  >
                    <span class="min-w-0 truncate text-[15px] font-medium text-stone-200">
                      {opponent["name"]}
                    </span>
                    <span class="shrink-0 font-mono text-[13px]">
                      <span class="font-bold text-emerald-400">{opponent["wins"]}W</span>
                      <span class="mx-1.5 text-stone-600">-</span>
                      <span class="font-bold text-rose-400">{opponent["losses"]}L</span>
                    </span>
                  </div>
                </div>
              </.card>

              <.card class="p-5 lg:col-span-2">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Recent sets
                  </h2>
                  <span class="text-sm text-stone-500">(latest first)</span>
                </div>
                <div id="recent-sets" class="mt-5 space-y-1">
                  <div class="hidden only:block text-sm text-stone-500">No recent sets.</div>
                  <div
                    :for={set <- @stats["recent_sets"]}
                    class="flex flex-col items-start justify-between gap-2 rounded-md px-4 py-3.5 transition-colors hover:bg-stone-900/60 sm:flex-row sm:items-center sm:gap-4"
                  >
                    <div class="min-w-0">
                      <div class="truncate text-[15px] font-medium text-stone-200">
                        {set["opponent"]}
                      </div>
                      <div class="mt-1 truncate text-sm text-stone-400">
                        {set["round"]} · {set["event"]} · {relative_time(set["completed_at"])}
                      </div>
                    </div>
                    <div class="flex shrink-0 items-center gap-2">
                      <span class={[
                        "rounded-md px-2.5 py-1 font-mono text-[13px] font-bold",
                        score_class(set)
                      ]}>
                        {set["score_us"]}-{set["score_them"]}
                      </span>
                      <span class={["size-1.5 shrink-0 rounded-full", result_dot(set)]}></span>
                    </div>
                  </div>
                </div>
              </.card>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp set_history_label(stats) do
    "last #{stats["completed_sets"]} completed sets of #{stats["sets_seen"]} fetched"
  end

  defp char_pct(char, stats) do
    denominator = Enum.reduce(stats["characters"], 0, fn c, acc -> acc + c["games"] end)

    if denominator == 0, do: 0, else: trunc(char["games"] * 100 / denominator)
  end

  defp score_class(set) do
    if set["won"], do: "bg-emerald-500/10 text-emerald-300", else: "bg-rose-500/10 text-rose-300"
  end

  defp result_dot(set) do
    if set["won"], do: "bg-emerald-400", else: "bg-rose-400"
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
