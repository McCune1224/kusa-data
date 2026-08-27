defmodule KusaDataWeb.PlayerLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Stats

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       stats: nil,
       graph: nil,
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
        graph: nil,
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
        graph = build_graph(stats)

        socket =
          assign(socket, stats: stats, graph: graph, error: nil, loading: false, stats_ref: nil)

        {:noreply, push_event(socket, "atlas:data", %{type: "network", graph: graph})}

      {:error, reason} ->
        {:noreply, assign(socket, stats: nil, graph: nil, error: reason, loading: false)}
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

    socket = assign(socket, stats: nil, graph: nil, loading: true)
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
       socket
       |> put_flash(
         :info,
         "Login is optional — it's only used to save your watches and bookmarks."
       )
       |> push_navigate(
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

  defp build_graph(stats) do
    player_id = stats["player_id"]
    gamer_tag = stats["gamer_tag"] || "Player #{player_id}"
    wins = stats["wins"] || 0
    losses = stats["losses"] || 0

    focal = %{
      "player_id" => player_id,
      "gamer_tag" => gamer_tag,
      "is_focal" => true,
      "weight" => max(wins + losses, 1)
    }

    opponents = stats["opponents"] || []

    {nodes, edges} =
      Enum.reduce(opponents, {[focal], []}, fn opp, {ns, es} ->
        case opp["opponent_player_id"] do
          nil ->
            {ns, es}

          opp_id ->
            node = %{
              "player_id" => opp_id,
              "gamer_tag" => opp["name"],
              "is_focal" => false,
              "weight" => opp["total"] || 1
            }

            edge = %{
              "source" => player_id,
              "target" => opp_id,
              "weight" => opp["total"] || 1
            }

            {[node | ns], [edge | es]}
        end
      end)

    %{"nodes" => Enum.reverse(nodes), "edges" => Enum.reverse(edges)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="space-y-4 animate-fade-up">
        <%= cond do %>
          <% is_nil(@stats) and @loading -> %>
            <div class="space-y-3">
              <div class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)] p-6">
                <div class="skeleton h-3 w-32 rounded-md"></div>
                <div class="mt-5 flex items-center gap-4">
                  <div class="skeleton size-12 rounded-full"></div>
                  <div class="space-y-2.5">
                    <div class="skeleton h-8 w-56 rounded-md"></div>
                    <div class="skeleton h-4 w-72 rounded-md"></div>
                  </div>
                </div>
              </div>
              <div class="grid gap-3 lg:grid-cols-[1.1fr_0.9fr]">
                <div class="grid grid-cols-2 gap-3">
                  <.skeleton :for={_ <- 1..4} class="h-24 rounded-[20px]" />
                </div>
                <.skeleton class="h-[280px] rounded-[20px]" />
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
            <div class="flex items-center justify-between">
              <p class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                Player analytics
              </p>
              <span class="hidden items-center gap-1.5 rounded-full border border-[var(--border)] bg-[var(--surface)] px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)] sm:inline-flex">
                <span class="size-1.5 rounded-full bg-[var(--accent)]"></span> Noir Bento
              </span>
            </div>

            <div class="flex flex-wrap items-center gap-2">
              <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={back_path(@game)}>
                Back
              </.btn>
              <%= if @game do %>
                <.link
                  navigate={~p"/game/#{@game}"}
                  class="rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 py-1 font-mono text-xs text-[var(--muted)] transition-colors hover:border-[var(--border2)] hover:text-[var(--text)]"
                >
                  {game_label(@game)}
                </.link>
              <% end %>
              <span class="mx-1 hidden h-5 w-px bg-[var(--border)] sm:block"></span>
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

            <.card class="p-6">
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div class="flex min-w-0 items-center gap-4">
                  <%= if @stats["avatar_url"] do %>
                    <img
                      src={@stats["avatar_url"]}
                      alt={@stats["gamer_tag"] || "player"}
                      class="size-14 shrink-0 rounded-full border border-[var(--border)] object-cover"
                    />
                  <% else %>
                    <.avatar name={@stats["gamer_tag"]} class="size-14 text-base" />
                  <% end %>
                  <div class="min-w-0">
                    <div class="flex min-w-0 flex-wrap items-center gap-2">
                      <%= if @stats["prefix"] && @stats["prefix"] != "" do %>
                        <span class="shrink-0 rounded-full bg-[var(--surface2)] px-2.5 py-1 font-mono text-xs font-semibold uppercase tracking-wide text-[var(--text)] ring-1 ring-[var(--border)]">
                          {@stats["prefix"]}
                        </span>
                      <% end %>
                      <h1 class="truncate text-3xl font-semibold tracking-tight text-[var(--text)]">
                        {@stats["gamer_tag"]}
                      </h1>
                    </div>
                    <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 font-mono text-[13px] text-[var(--muted)]">
                      <span>player {@stats["player_id"]}</span>
                      <span aria-hidden="true" class="text-[var(--border2)]">·</span>
                      <span>{set_history_label(@stats)}</span>
                      <%= if @stats["location"] do %>
                        <span class="flex items-center gap-1 font-sans">
                          <.icon name="hero-map-pin" class="size-3.5 text-[var(--muted)]" />
                          {@stats["location"]}
                        </span>
                      <% end %>
                    </div>
                    <%= if @stats["bio"] && @stats["bio"] != "" do %>
                      <p class="mt-2 max-w-xl text-sm leading-relaxed text-[var(--muted)]">
                        {@stats["bio"]}
                      </p>
                    <% end %>
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
            </.card>

            <div class="grid gap-3 lg:grid-cols-[1.15fr_0.85fr]">
              <.card class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Stats bento
                  </h2>
                  <span class="rounded-full bg-[var(--accent)] px-2 py-0.5 text-[10px] font-bold uppercase tracking-widest text-[#08070b]">Live</span>
                </div>
                <div class="mt-4 grid grid-cols-2 gap-3">
                  <.stat label="Wins" value={@stats["wins"]} value_class="text-emerald-400" />
                  <.stat label="Losses" value={@stats["losses"]} value_class="text-rose-400" />
                  <.stat label="Win rate" value={percent(@stats["win_rate"])} />
                  <.stat
                    label="Sets analyzed"
                    value={"last #{@stats["completed_sets"]}"}
                    sub={"of #{@stats["sets_seen"]} fetched"}
                  />
                </div>
                <div class="mt-4 flex items-center gap-2 text-xs text-[var(--muted)]">
                  <span class="size-1.5 rounded-full bg-emerald-400"></span>
                  W <span class="size-1.5 rounded-full bg-rose-400"></span>
                  L <span class="ml-auto font-mono">{percent(@stats["win_rate"])} overall</span>
                </div>
              </.card>

              <.card class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Ego network
                  </h2>
                  <span class="font-mono text-[11px] text-[var(--muted)]">
                    {length(@stats["opponents"] || [])} opponents · graph
                  </span>
                </div>
                <div
                  id="player-network"
                  phx-hook="AtlasHook"
                  phx-update="ignore"
                  class="atlas-canvas mt-4 h-[300px] w-full overflow-hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40"
                >
                </div>
                <p class="mt-3 text-xs leading-relaxed text-[var(--muted)]">
                  Tap a node to jump to that opponent. Focal player highlighted in <span class="text-[var(--accent)]">accent</span>.
                </p>
              </.card>
            </div>

            <div class="grid gap-3 lg:grid-cols-2">
              <.card class="p-5">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Character usage
                  </h2>
                  <span class="text-sm text-[var(--muted)]">(recent sets)</span>
                </div>
                <div id="characters" class="mt-5 space-y-3">
                  <div class="hidden only:block text-sm text-[var(--muted)]">
                    No character data yet.
                  </div>
                  <div :for={char <- @stats["characters"]} class="flex items-center gap-3">
                    <span class="w-28 shrink-0 truncate text-[15px] font-medium text-[var(--text)]">
                      {char["name"]}
                    </span>
                    <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-[var(--surface2)] ring-1 ring-[var(--border)]">
                      <div
                        class="h-full rounded-full bg-[var(--accent)] transition-all duration-300"
                        style={"width: #{char_pct(char, @stats)}%"}
                      >
                      </div>
                    </div>
                    <span class="w-14 shrink-0 text-right font-mono text-[13px] text-[var(--muted)]">
                      {char["games"]} game{plural(char["games"])}
                    </span>
                  </div>
                </div>
              </.card>

              <.card class="p-5">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Head-to-head
                  </h2>
                  <span class="text-sm text-[var(--muted)]">(top opponents)</span>
                </div>
                <div class="mt-5 space-y-1">
                  <div class="hidden only:block text-sm text-[var(--muted)]">No opponents yet.</div>
                  <div
                    :for={opponent <- @stats["opponents"]}
                    class="flex items-center justify-between gap-3 rounded-[12px] border border-transparent px-3.5 py-3 transition-colors hover:border-[var(--border)] hover:bg-[var(--surface2)]/60"
                  >
                    <span class="min-w-0 truncate text-[15px] font-medium text-[var(--text)]">
                      {opponent["name"]}
                      <%= if opponent["unresolved"] do %>
                        <span class="ml-1.5 text-xs text-[var(--muted)]">(unresolved)</span>
                      <% end %>
                    </span>
                    <span class="flex shrink-0 items-center gap-2 font-mono text-[13px]">
                      <span class="font-bold text-emerald-400">{opponent["wins"]}W</span>
                      <span class="text-[var(--muted)]">-</span>
                      <span class="font-bold text-rose-400">{opponent["losses"]}L</span>
                      <%= if opponent["opponent_player_id"] do %>
                        <.link
                          navigate={"/player/#{@stats["player_id"]}/h2h?vs=#{opponent["opponent_player_id"]}" <> h2h_query(@game)}
                          class="ml-1 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2 py-0.5 text-[11px] uppercase tracking-wide text-[var(--muted)] transition-colors hover:border-[var(--accent)]/40 hover:text-[var(--text)]"
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
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Character matchups
                  </h2>
                  <span class="text-sm text-[var(--muted)]">(wins / games)</span>
                </div>
                <div id="matchup-grid" class="mt-5 overflow-x-auto">
                  <%= if @stats["matchup_grid"]["rows"] == [] do %>
                    <div class="text-sm text-[var(--muted)]">No matchup data yet.</div>
                  <% else %>
                    <table class="w-full border-collapse text-sm">
                      <thead>
                        <tr>
                          <th class="border-b border-[var(--border)] px-3 py-2 text-left text-xs font-medium uppercase tracking-[0.14em] text-[var(--muted)]">
                            You
                          </th>
                          <th
                            :for={column <- @stats["matchup_grid"]["columns"]}
                            class="border-b border-[var(--border)] px-3 py-2 text-right font-mono text-xs text-[var(--muted)]"
                          >
                            vs {column}
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={row <- @stats["matchup_grid"]["rows"]}>
                          <td class="border-b border-[var(--border)]/60 px-3 py-2 font-medium text-[var(--text)]">
                            {row["character"]}
                          </td>
                          <td
                            :for={cell <- row["cells"]}
                            class={[
                              "border-b border-[var(--border)]/60 px-3 py-2 text-right font-mono",
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
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Recent events
                  </h2>
                  <span class="text-sm text-[var(--muted)]">(most recent first)</span>
                </div>
                <div id="recent-events" class="mt-5 grid gap-3 sm:grid-cols-2">
                  <div class="hidden only:block text-sm text-[var(--muted)]">No events yet.</div>
                  <.link
                    :for={event <- @stats["recent_events"]}
                    navigate={"/event/#{event["event_id"]}" <> event_game_query(event)}
                    id={"recent-event-#{event["event_id"]}"}
                    class="group rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40 px-4 py-3 transition-colors hover:border-[var(--accent)]/30 hover:bg-[var(--surface2)]/70"
                  >
                    <div class="flex items-center justify-between gap-3">
                      <span class="min-w-0 truncate text-[15px] font-medium text-[var(--text)] transition-colors group-hover:text-[var(--accent)]">
                        {event["name"]}
                      </span>
                      <span class={[
                        "shrink-0 font-mono text-[13px]",
                        event["losses"] == 0 && event["wins"] > 0 && "text-emerald-400",
                        !(event["losses"] == 0 && event["wins"] > 0) && "text-[var(--text)]"
                      ]}>
                        {event["wins"]}-{event["losses"]}
                      </span>
                    </div>
                    <div class="mt-1 flex items-center gap-2 text-[13px] text-[var(--muted)]">
                      <%= if event["game_slug"] do %>
                        <.badge tone="neutral">{game_label(event["game_slug"])}</.badge>
                      <% end %>
                      <span>{event["sets"]} sets</span>
                      <%= if event["last_played"] do %>
                        <span aria-hidden="true">·</span>
                        <span>{relative_time(event["last_played"])}</span>
                      <% end %>
                    </div>
                  </.link>
                </div>
              </.card>

              <.card class="p-5 lg:col-span-2">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Recent sets
                  </h2>
                  <span class="text-sm text-[var(--muted)]">(latest first)</span>
                </div>
                <div id="recent-sets" class="mt-5 space-y-1">
                  <div class="hidden only:block text-sm text-[var(--muted)]">No recent sets.</div>
                  <div
                    :for={set <- @stats["recent_sets"]}
                    class="flex flex-col items-start justify-between gap-2 rounded-[12px] border border-transparent px-4 py-3.5 transition-colors hover:border-[var(--border)] hover:bg-[var(--surface2)]/50 sm:flex-row sm:items-center sm:gap-4"
                  >
                    <div class="min-w-0">
                      <div class="truncate text-[15px] font-medium text-[var(--text)]">
                        {set["opponent"]}
                      </div>
                      <div class="mt-1 truncate text-sm text-[var(--muted)]">
                        {set["round"]} · {set["event"]} · {relative_time(set["completed_at"])}
                      </div>
                    </div>
                    <div class="flex shrink-0 items-center gap-2">
                      <span class={[
                        "rounded-full px-2.5 py-1 font-mono text-[13px] font-bold",
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

  defp event_game_query(%{"game_slug" => slug}) when is_binary(slug), do: "?game=#{slug}"
  defp event_game_query(_), do: ""

  defp cell_class(cell) do
    if cell["games"] > 0 and cell["wins"] * 2 >= cell["games"] do
      "text-emerald-400"
    else
      "text-[var(--muted)]"
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
    if set["won"], do: "bg-emerald-500/15 text-emerald-300", else: "bg-rose-500/15 text-rose-300"
  end

  defp result_dot(set) do
    if set["won"], do: "bg-emerald-400", else: "bg-rose-400"
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
