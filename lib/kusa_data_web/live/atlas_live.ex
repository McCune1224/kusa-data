defmodule KusaDataWeb.AtlasLive do
  @moduledoc """
  Blocky ranked Atlas for the 2026 Melee season.

  Primary view is a dense ranked grid and table. Data loads asynchronously so
  the page renders a skeleton immediately and fills when `KusaData.Atlas.map_data/0`
  resolves. A small secondary minimap (grid-placed, max radius 14) is available
  but never the primary and never geographic-clustered. `/atlas/player/:id`
  renders a player's opponent network as a server-side SVG.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Atlas
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       view: :map,
       loading: false,
       map_loaded: false,
       tiles: [],
       ranked: [],
       max_tournaments: 0,
       bubbles: [],
       grid_lines: [],
       region_count: 0,
       total_tournaments: 0,
       total_attendees: 0,
       minimap: [],
       gamer_tag: nil,
       graph_nodes: [],
       graph_edges: [],
       excluded: 0,
       opponent_count: 0
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      case Map.get(params, "id") do
        nil -> schedule_map_load(socket)
        id -> load_player(socket, id)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:load_map, socket) do
    regions = safe_map_data()
    tiles = build_tiles(regions)
    ranked = tiles
    max_t = tiles |> Enum.map(& &1.tournaments) |> Enum.max(fn -> 0 end)
    minimap = build_minimap(tiles, max_t)

    {:noreply,
     assign(socket,
       view: :map,
       loading: false,
       map_loaded: true,
       tiles: tiles,
       ranked: ranked,
       max_tournaments: max_t,
       bubbles: [],
       grid_lines: [],
       minimap: minimap,
       region_count: length(regions),
       total_tournaments: sum(regions, "tournaments"),
       total_attendees: sum(regions, "attendees")
     )}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp schedule_map_load(socket) do
    if socket.assigns.map_loaded or socket.assigns.loading do
      assign(socket, view: :map)
    else
      send(self(), :load_map)
      assign(socket, view: :map, loading: true)
    end
  end

  defp safe_map_data do
    case Atlas.map_data() do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp build_tiles(regions) do
    sorted = Enum.sort_by(regions, &(&1["tournaments"] || 0), :desc)
    max_c = sorted |> Enum.map(&(&1["tournaments"] || 0)) |> Enum.max(fn -> 0 end)

    Enum.map(sorted, fn region ->
      count = region["tournaments"] || 0
      attendees = region["attendees"] || 0
      pct = if max_c == 0, do: 0, else: round(count / max_c * 100)

      %{
        label: region["label"],
        country: region["country"],
        state: region["state"],
        tournaments: count,
        attendees: attendees,
        bar_pct: pct,
        key: to_string(region["country"]) <> "-" <> to_string(region["state"])
      }
    end)
  end

  defp build_minimap(tiles, max_t) do
    tiles
    |> Enum.with_index()
    |> Enum.map(fn {tile, idx} ->
      col = rem(idx, 10)
      row = div(idx, 10)
      x = col * 100 + 50
      y = row * 50 + 30
      r = scale_minimap_radius(tile.tournaments, max_t)
      %{x: x, y: y, r: r, label: tile.label}
    end)
  end

  defp scale_minimap_radius(_count, 0), do: 6.0

  defp scale_minimap_radius(count, max_c) do
    min_r = 6.0
    max_r = 14.0
    min_r + count / max_c * (max_r - min_r)
  end

  defp sum(regions, key) do
    Enum.reduce(regions, 0, fn region, acc -> acc + (region[key] || 0) end)
  end

  defp load_player(socket, id) when is_binary(id) do
    case Integer.parse(id) do
      {player_id, ""} -> do_load_player(socket, player_id)
      _ -> assign_empty_player(socket, id)
    end
  end

  defp do_load_player(socket, player_id) do
    case Players.atlas(player_id, %{}) do
      {:ok, map, _} -> assign_player(socket, map)
      _ -> assign_empty_player(socket, to_string(player_id))
    end
  end

  defp assign_player(socket, map) do
    nodes = map["nodes"] || []
    excluded = map["excluded_unresolved"] || 0
    {focal, opponents} = Enum.split_with(nodes, & &1["is_focal"])
    layout = build_graph(focal, opponents)

    assign(socket,
      view: :player,
      loading: false,
      map_loaded: false,
      gamer_tag: map["gamer_tag"],
      graph_nodes: layout.nodes,
      graph_edges: layout.edges,
      excluded: excluded,
      opponent_count: length(opponents),
      tiles: [],
      ranked: [],
      bubbles: [],
      grid_lines: [],
      minimap: [],
      region_count: 0,
      total_tournaments: 0,
      total_attendees: 0
    )
  end

  defp assign_empty_player(socket, id) do
    assign(socket,
      view: :player,
      loading: false,
      map_loaded: false,
      gamer_tag: "Player #{id}",
      graph_nodes: [],
      graph_edges: [],
      excluded: 0,
      opponent_count: 0,
      tiles: [],
      ranked: [],
      bubbles: [],
      grid_lines: [],
      minimap: [],
      region_count: 0,
      total_tournaments: 0,
      total_attendees: 0
    )
  end

  defp build_graph(focal, opponents) do
    cx = 500.0
    cy = 250.0

    focal_node = %{
      x: cx,
      y: cy,
      r: 26.0,
      gamer_tag: gamer_tag_of(focal),
      focal: true,
      weight: weight_of(focal)
    }

    n = length(opponents)
    ring = if n == 0, do: 0.0, else: 200.0

    nodes =
      opponents
      |> Enum.with_index()
      |> Enum.map(fn {opp, i} ->
        angle = 2.0 * :math.pi() * i / max(n, 1)
        ox = cx + ring * :math.cos(angle)
        oy = cy + ring * :math.sin(angle)

        %{
          x: ox,
          y: oy,
          r: scale_node_radius(opp["weight"]),
          gamer_tag: opp["gamer_tag"],
          focal: false,
          weight: opp["weight"]
        }
      end)

    edges = Enum.map(nodes, fn node -> %{x1: cx, y1: cy, x2: node.x, y2: node.y} end)

    %{nodes: [focal_node | nodes], edges: edges}
  end

  defp scale_node_radius(weight) when is_integer(weight) do
    8.0 + min(weight, 16) * 1.0
  end

  defp scale_node_radius(_), do: 8.0

  defp gamer_tag_of([focal | _]), do: focal["gamer_tag"]
  defp gamer_tag_of(_), do: nil

  defp weight_of([focal | _]), do: focal["weight"] || 0
  defp weight_of(_), do: 0

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:atlas}>
      <div id="atlas-live" class="animate-rise">
        <%= if @view == :map do %>
          <div class="mb-8 flex flex-col gap-2">
            <h1 class="font-display text-3xl font-bold tracking-tight text-ink">Atlas</h1>
            <p class="max-w-2xl text-sm text-muted">
              Where the Melee scene shows up. Dense ranked view of tournaments by region across the 2026 season.
            </p>
          </div>

          <div class="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <.stat label="Regions" value={to_string(@region_count)} />
            <.stat label="Tournaments" value={to_string(@total_tournaments)} />
            <.stat label="Attendees" value={to_string(@total_attendees)} />
            <.stat label="Season" value="2026" />
          </div>

          <%= if @loading do %>
            <div id="atlas-skeleton" class="space-y-6">
              <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <%= for _ <- 1..8 do %>
                  <div class="skeleton h-[132px] rounded-none border border-line bg-surface"></div>
                <% end %>
              </div>
              <div class="skeleton h-[240px] rounded-none border border-line bg-surface"></div>
            </div>
          <% else %>
            <%= if Enum.empty?(@tiles) do %>
              <.empty
                class="mt-6"
                icon="hero-map"
                title="No regions to map yet"
                description="Tournament regions will appear here once the season data loads."
              />
            <% else %>
              <div id="atlas-grid" class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <%= for tile <- @tiles do %>
                  <div class="atlas-tile flex flex-col justify-between rounded-none border border-line bg-surface p-4">
                    <div class="flex items-start justify-between gap-2">
                      <p class="text-xs font-bold uppercase tracking-[0.08em] text-muted">{tile.label}</p>
                      <span class="rounded-none border border-line bg-surface-2 px-2 py-0.5 text-xs font-mono font-semibold text-ink">
                        {tile.tournaments}
                      </span>
                    </div>
                    <div class="mt-3">
                      <p class="font-display text-2xl font-bold tracking-tight text-ink">{tile.tournaments}</p>
                      <p class="text-xs font-mono uppercase tracking-[0.06em] text-faint">
                        {tile.attendees} attendees
                      </p>
                    </div>
                    <div class="mt-4 h-1 w-full bg-surface-3">
                      <div class="atlas-bar h-1 bg-accent" style={"width: #{tile.bar_pct}%"}></div>
                    </div>
                    <p class="mt-2 text-xs font-mono text-faint">{tile.country} · {tile.state}</p>
                  </div>
                <% end %>
              </div>

              <div class="mt-8 overflow-x-auto rounded-none border border-line bg-surface">
                <table class="w-full border-collapse text-sm">
                  <thead>
                    <tr class="border-b border-line bg-surface-2 text-left">
                      <th class="px-4 py-2 text-xs font-bold uppercase tracking-[0.08em] text-muted">Rank</th>
                      <th class="px-4 py-2 text-xs font-bold uppercase tracking-[0.08em] text-muted">Region</th>
                      <th class="px-4 py-2 text-right text-xs font-bold uppercase tracking-[0.08em] text-muted">
                        Tournaments
                      </th>
                      <th class="px-4 py-2 text-right text-xs font-bold uppercase tracking-[0.08em] text-muted">
                        Attendees
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {tile, idx} <- Enum.with_index(@ranked, 1) do %>
                      <tr class="border-b border-line last:border-0">
                        <td class="px-4 py-2 font-mono text-xs text-faint">#{idx}</td>
                        <td class="px-4 py-2 font-semibold text-ink">{tile.label}</td>
                        <td class="px-4 py-2 text-right font-mono text-ink">{tile.tournaments}</td>
                        <td class="px-4 py-2 text-right font-mono text-muted">{tile.attendees}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <%= if length(@minimap) > 0 do %>
                <div class="atlas-canvas mt-8 rounded-none border border-line bg-surface p-2">
                  <p class="mb-2 text-xs font-bold uppercase tracking-[0.08em] text-muted">Minimap · grid-placed · r 6–14</p>
                  <svg
                    class="atlas-svg"
                    viewBox="0 0 1000 320"
                    role="img"
                    aria-label="Region minimap grid"
                  >
                    <%= for dot <- @minimap do %>
                      <g class="atlas-bubble">
                        <circle class="atlas-bubble-fill" cx={dot.x} cy={dot.y} r={dot.r}>
                          <title>{dot.label}</title>
                        </circle>
                      </g>
                    <% end %>
                  </svg>
                </div>
              <% end %>
            <% end %>
          <% end %>
        <% else %>
          <div class="mb-8 flex flex-col gap-2">
            <h1 class="font-display text-3xl font-bold tracking-tight text-ink">{@gamer_tag}</h1>
            <p class="max-w-2xl text-sm text-muted">
              Opponent network — bubble size reflects the number of shared sets.
              <%= if @opponent_count > 0 do %>
                {@opponent_count} opponent{if(@opponent_count == 1, do: "", else: "s")} mapped.
              <% end %>
            </p>
          </div>

          <%= if @excluded > 0 do %>
            <p class="mb-4 text-xs text-faint">
              {@excluded} unresolved opponent{if(@excluded == 1, do: "", else: "s")} not shown.
            </p>
          <% end %>

          <%= if Enum.empty?(@graph_nodes) do %>
            <.empty
              class="mt-6"
              icon="hero-user-group"
              title="No network data"
              description="We couldn't build an opponent network for this player yet."
            />
          <% else %>
            <div class="atlas-canvas rounded-none border border-line bg-surface" id="atlas-network">
              <svg
                class="atlas-svg"
                viewBox="0 0 1000 500"
                role="img"
                aria-label={"Opponent network for #{@gamer_tag}"}
              >
                <%= for edge <- @graph_edges do %>
                  <line class="atlas-edge" x1={edge.x1} y1={edge.y1} x2={edge.x2} y2={edge.y2} />
                <% end %>
                <%= for node <- @graph_nodes do %>
                  <g class={["atlas-node", node.focal && "atlas-node-focal"]}>
                    <circle class="atlas-node-fill" cx={node.x} cy={node.y} r={node.r}>
                      <title>{node.gamer_tag}</title>
                    </circle>
                    <text class="atlas-label" x={node.x} y={node.y - node.r - 4} text-anchor="middle">
                      {node.gamer_tag}
                    </text>
                  </g>
                <% end %>
              </svg>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
