defmodule KusaDataWeb.PlayerLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Stats

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       stats: nil,
       error: nil,
       loading: true,
       player_id: nil,
       game: nil,
       watched: false,
       nav: :tournaments
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_id = params["id"]
    game = valid_game(params["game"])

    socket =
      assign(socket,
        player_id: player_id,
        game: game,
        watched: watch_status(socket.assigns.current_user, player_id),
        stats: nil,
        error: nil,
        loading: true
      )

    socket = spawn_stats_load(socket, player_id, game)
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

  defp spawn_stats_load(socket, player_id, game) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:stats_loaded, ref, Stats.for_player(player_id, game)})
    end)

    assign(socket, stats_ref: ref)
  end

  defp valid_game(nil), do: nil

  defp valid_game(slug) when is_binary(slug) do
    case Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> nil
    end
  end

  defp valid_game(_), do: nil

  @impl true
  def handle_event("refresh", _params, socket) do
    player_id = socket.assigns.player_id || socket.assigns.stats["player_id"]
    Stats.clear_cache(player_id, socket.assigns.game)

    socket = assign(socket, stats: nil, loading: true)
    {:noreply, spawn_stats_load(socket, player_id, socket.assigns.game)}
  end

  @impl true
  def handle_event("watch", _params, socket) do
    if socket.assigns.current_user do
      {:ok, _} =
        KusaData.Watches.watch(socket.assigns.current_user, "player", socket.assigns.player_id)

      {:noreply, assign(socket, watched: true) |> put_flash(:info, "Player watch enabled.")}
    else
      {:noreply,
       push_navigate(
         socket,
         to:
           "/auth?mode=login&return_to=#{URI.encode_www_form("/player/#{socket.assigns.player_id}")}"
       )}
    end
  end

  @impl true
  def handle_event("unwatch", _params, socket) do
    if socket.assigns.current_user do
      :ok =
        KusaData.Watches.unwatch(socket.assigns.current_user, "player", socket.assigns.player_id)

      {:noreply, assign(socket, watched: false) |> put_flash(:info, "Player watch removed.")}
    else
      {:noreply, socket}
    end
  end

  defp watch_status(nil, _id), do: false

  defp watch_status(user, id) do
    if KusaData.Accounts.repo_configured?(),
      do: KusaData.Watches.watched?(user, "player", id),
      else: false
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
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
            <div class="mt-3 flex flex-wrap items-center gap-2">
              <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={back_path(@game)}>
                Back
              </.btn>
              <%= if @game do %>
                <.link
                  navigate={~p"/game/#{@game}"}
                  class="rounded-none border border-stone-700/70 px-2.5 py-1 font-mono text-xs text-stone-400 transition-colors hover:text-stone-100"
                >
                  {game_label(@game)}
                </.link>
              <% end %>
              <span class="mx-1 hidden h-5 w-px bg-stone-800 sm:block"></span>
              <.btn
                variant="ghost"
                size="sm"
                navigate={"/player/#{@stats["player_id"]}/history" <> game_query(@game)}
              >
                Full history
              </.btn>
              <.btn
                variant="ghost"
                size="sm"
                navigate={"/player/#{@stats["player_id"]}/trend" <> game_query(@game)}
              >
                Trend
              </.btn>
              <.btn
                variant="ghost"
                size="sm"
                navigate={"/players/compare?a=#{@stats["player_id"]}" <> compare_query(@game)}
              >
                Compare
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
              <div class="flex items-center gap-1">
                <%= if @watched do %>
                  <.btn variant="ghost" size="sm" icon="hero-bell-slash" phx-click="unwatch">
                    Watching
                  </.btn>
                <% else %>
                  <.btn variant="ghost" size="sm" icon="hero-bell" phx-click="watch">
                    Watch
                  </.btn>
                <% end %>
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
                      <%= if opponent["unresolved"] do %>
                        <span class="ml-1.5 text-xs text-stone-600">(unresolved)</span>
                      <% end %>
                    </span>
                    <span class="flex shrink-0 items-center gap-2 font-mono text-[13px]">
                      <span class="font-bold text-emerald-400">{opponent["wins"]}W</span>
                      <span class="text-stone-600">-</span>
                      <span class="font-bold text-rose-400">{opponent["losses"]}L</span>
                      <%= if opponent["opponent_player_id"] do %>
                        <.link
                          navigate={"/player/#{@stats["player_id"]}/h2h?vs=#{opponent["opponent_player_id"]}" <> h2h_query(@game)}
                          class="ml-1 rounded-none border border-stone-700/70 px-1.5 py-0.5 text-[11px] uppercase tracking-wide text-stone-400 transition-colors hover:text-stone-100"
                        >
                          vs
                        </.link>
                      <% end %>
                    </span>
                  </div>
                </div>
              </.card>

              <.card class="p-5 lg:col-span-2">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Character matchups
                  </h2>
                  <span class="text-sm text-stone-500">(wins / games)</span>
                </div>
                <div id="matchup-grid" class="mt-5 overflow-x-auto">
                  <%= if @stats["matchup_grid"]["rows"] == [] do %>
                    <div class="text-sm text-stone-500">No matchup data yet.</div>
                  <% else %>
                    <table class="w-full border-collapse text-sm">
                      <thead>
                        <tr>
                          <th class="border-b border-stone-800 px-3 py-2 text-left text-xs font-medium uppercase tracking-[0.14em] text-stone-500">
                            You
                          </th>
                          <th
                            :for={column <- @stats["matchup_grid"]["columns"]}
                            class="border-b border-stone-800 px-3 py-2 text-right font-mono text-xs text-stone-400"
                          >
                            vs {column}
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={row <- @stats["matchup_grid"]["rows"]}>
                          <td class="border-b border-stone-800/60 px-3 py-2 font-medium text-stone-300">
                            {row["character"]}
                          </td>
                          <td
                            :for={cell <- row["cells"]}
                            class={[
                              "border-b border-stone-800/60 px-3 py-2 text-right font-mono",
                              cell_class(cell)
                            ]}
                          >
                            <%= if cell["games"] > 0 do %>
                              {cell["wins"]}/{cell["games"]}
                            <% else %>
                              —
                            <% end %>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  <% end %>
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

  defp back_path(nil), do: ~p"/"
  defp back_path(game), do: ~p"/game/#{game}"

  defp game_query(nil), do: ""
  defp game_query(game), do: "?game=#{game}"

  defp h2h_query(nil), do: ""
  defp h2h_query(game), do: "&game=#{game}"

  defp compare_query(nil), do: ""
  defp compare_query(game), do: "&game=#{game}"

  defp cell_class(cell) do
    if cell["games"] > 0 and cell["wins"] * 2 >= cell["games"] do
      "text-emerald-400"
    else
      "text-stone-500"
    end
  end

  defp game_label(slug) do
    case Games.by_slug(slug) do
      %{short_name: name} -> name
      nil -> slug
    end
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
