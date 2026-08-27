defmodule KusaDataWeb.PlayerTrendLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :tournaments,
       player_id: nil,
       game: nil,
       data: nil,
       graph: nil,
       error: nil,
       loading: true
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_id = params["id"]
    game = valid_game(params["game"])

    socket =
      socket
      |> assign(player_id: player_id, data: nil, graph: nil, error: nil, loading: true)
      |> spawn_load(player_id, game)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trend_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        graph = build_trend_graph(data, socket.assigns.player_id)

        socket =
          assign(socket, data: data, graph: graph, error: nil, loading: false, load_ref: nil)

        {:noreply, push_event(socket, "atlas:data", %{type: "network", graph: graph})}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, graph: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:trend_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket, player_id, game) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:trend_loaded, ref, Players.trend(player_id, %{game: game})})
    end)

    assign(socket, load_ref: ref)
  end

  defp build_trend_graph(data, player_id) do
    pid_int =
      case Integer.parse(to_string(player_id)) do
        {n, ""} -> n
        _ -> player_id
      end

    gamer_tag = (data && data["gamer_tag"]) || "Player #{player_id}"
    buckets = (data && data["buckets"]) || []

    focal = %{
      "player_id" => pid_int,
      "gamer_tag" => gamer_tag,
      "is_focal" => true,
      "weight" => max(length(buckets), 1)
    }

    month_nodes =
      buckets
      |> Enum.take(8)
      |> Enum.with_index()
      |> Enum.map(fn {bucket, idx} ->
        %{
          "player_id" => pid_int + 10_000 + idx,
          "gamer_tag" => bucket["month"],
          "is_focal" => false,
          "weight" => max(bucket["sets"] || 1, 1)
        }
      end)

    edges =
      month_nodes
      |> Enum.map(fn node ->
        %{"source" => pid_int, "target" => node["player_id"], "weight" => node["weight"]}
      end)

    nodes = [focal | month_nodes]

    # If no buckets, add placeholder node so graph renders
    nodes =
      if month_nodes == [] do
        [
          focal,
          %{
            "player_id" => pid_int + 999_999,
            "gamer_tag" => "No trend",
            "is_focal" => false,
            "weight" => 1
          }
        ]
      else
        nodes
      end

    %{"nodes" => nodes, "edges" => edges}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="space-y-4 animate-fade-up">
        <.btn
          variant="ghost"
          size="sm"
          icon="hero-arrow-left"
          navigate={~p"/player/#{@player_id}"}
        >
          Player page
        </.btn>

        <.card class="p-6">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
            Player trend
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[var(--text)]">
            {if @data, do: @data["gamer_tag"], else: "Player #{@player_id}"}
          </h1>
          <p class="mt-1 text-[15px] text-[var(--muted)]">
            Monthly win rate and best placement{game_suffix(@game)}
          </p>
          <%= if @data && @data["buckets"] != [] do %>
            <div class="mt-4">
              <p class="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">
                Win rate sparkline
              </p>
              <svg
                viewBox="0 0 300 40"
                class="mt-2 h-10 w-full"
                role="img"
                aria-label="Trend sparkline"
              >
                <polyline
                  fill="none"
                  stroke="var(--accent)"
                  stroke-width="2"
                  stroke-linejoin="round"
                  stroke-linecap="round"
                  points={trend_sparkline_points(@data["buckets"])}
                />
                <polyline
                  fill="none"
                  stroke="rgba(154,149,176,0.2)"
                  stroke-width="1"
                  stroke-dasharray="3 3"
                  points="0,20 300,20"
                />
              </svg>
              <div class="mt-1 flex justify-between font-mono text-[11px] text-[var(--muted)]">
                <span>{(@data["buckets"] |> hd())["month"]}</span>
                <span>{(@data["buckets"] |> List.last())["month"]}</span>
              </div>
            </div>
          <% end %>
        </.card>

        <div class="grid gap-3 lg:grid-cols-[1.25fr_0.75fr]">
          <div>
            <%= if @loading do %>
              <div class="space-y-3">
                <.skeleton :for={_ <- 1..6} class="h-16 w-full rounded-[20px]" />
              </div>
            <% else %>
              <%= if @data == nil || @data["buckets"] == [] do %>
                <.empty_state icon="hero-chart-bar" title="No trend data">
                  <:body>This player has no completed sets in the selected scope.</:body>
                </.empty_state>
              <% else %>
                <div id="trend-buckets" class="space-y-3">
                  <div
                    :for={bucket <- @data["buckets"]}
                    class="flex items-center gap-4 rounded-[20px] border border-[var(--border)] bg-[var(--surface)] px-5 py-4"
                  >
                    <span class="w-16 shrink-0 font-mono text-sm text-[var(--muted)]">
                      {bucket["month"]}
                    </span>
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center justify-between text-xs text-[var(--muted)]">
                        <span>{bucket["wins"]}W-{bucket["losses"]}L</span>
                        <span>{percent(bucket["win_rate"])}</span>
                      </div>
                      <div class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[var(--surface2)] ring-1 ring-[var(--border)]">
                        <div
                          class="h-full rounded-full bg-[var(--accent)] transition-all duration-300"
                          style={"width: #{min(bucket["win_rate"], 100)}%"}
                        >
                        </div>
                      </div>
                    </div>
                    <span class="w-24 shrink-0 text-right font-mono text-sm">
                      <%= if bucket["best_placement"] do %>
                        <span class="text-[var(--text)]">best #{ordinal(bucket["best_placement"])}</span>
                      <% else %>
                        <span class="text-[var(--muted)]">no placement</span>
                      <% end %>
                    </span>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <.card class="p-5">
            <div class="flex items-center justify-between">
              <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                Trend graph
              </h2>
              <span class="font-mono text-[11px] text-[var(--muted)]">months · network</span>
            </div>
            <div
              id="player-network"
              phx-hook="AtlasHook"
              phx-update="ignore"
              class="atlas-canvas mt-4 h-[320px] w-full overflow-hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40"
            >
            </div>
            <p class="mt-3 text-xs text-[var(--muted)]">
              Each peripheral node is a month bucket sized by sets.
            </p>
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp trend_sparkline_points(buckets) do
    total = max(length(buckets), 1)

    buckets
    |> Enum.with_index()
    |> Enum.map(fn {bucket, idx} ->
      x = if total == 1, do: 150, else: idx * 300 / (total - 1)
      y = 38 - bucket["win_rate"] * 0.34
      "#{Float.round(x * 1.0, 1)},#{Float.round(y * 1.0, 1)}"
    end)
    |> Enum.join(" ")
  end

  defp game_suffix(nil), do: ""
  defp game_suffix(game), do: " · #{game}"

  defp ordinal(1), do: "1st"
  defp ordinal(2), do: "2nd"
  defp ordinal(3), do: "3rd"
  defp ordinal(n), do: "#{n}th"

  defp valid_game(nil), do: nil

  defp valid_game(slug) do
    case Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> nil
    end
  end
end
