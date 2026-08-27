defmodule KusaDataWeb.AtlasLive do
  @moduledoc """
  Geographic bubble map of the Melee scene.

  `/atlas` renders a server-side SVG bubble map of tournament regions using
  the static centroids from `KusaData.Atlas.map_data/0`. `/atlas/player/:id`
  renders a player's opponent network (also server-side SVG) from
  `KusaData.Players.atlas/2`. Both render without any JS hook.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Atlas
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       view: :map,
       bubbles: [],
       grid_lines: [],
       region_count: 0,
       total_tournaments: 0,
       total_attendees: 0,
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
        nil -> load_map(socket)
        id -> load_player(socket, id)
      end

    {:noreply, socket}
  end

  # --- Map (region) view ----------------------------------------------------

  defp load_map(socket) do
    regions = safe_map_data()
    bubbles = build_bubbles(regions)

    assign(socket,
      view: :map,
      bubbles: bubbles,
      grid_lines: build_grid(),
      region_count: length(regions),
      total_tournaments: sum(regions, "tournaments"),
      total_attendees: sum(regions, "attendees"),
      gamer_tag: nil,
      graph_nodes: [],
      graph_edges: [],
      excluded: 0,
      opponent_count: 0
    )
  end

  defp safe_map_data do
    case Atlas.map_data() do
      list when is_list(list) -> list
      _ -> []
    end
  end

  # Project lat/lng to the 1000x500 equirectangular viewBox.
  defp project(lat, lng) do
    x = (lng + 180) / 360 * 1000
    y = (90 - lat) / 180 * 500
    {x, y}
  end

  defp build_bubbles(regions) do
    counts = Enum.map(regions, &(&1["tournaments"] || 0))
    {min_c, max_c} = bounds(counts)

    Enum.map(regions, fn region ->
      {x, y} = project(region["lat"], region["lng"])
      count = region["tournaments"] || 0

      %{
        key: to_string(region["country"]) <> "-" <> to_string(region["state"]),
        x: x,
        y: y,
        r: scale_radius(count, min_c, max_c),
        label: region["label"],
        sub: "#{count} event#{if(count == 1, do: "", else: "s")}"
      }
    end)
  end

  defp bounds([]), do: {0, 0}

  defp bounds(counts) do
    {Enum.min(counts), Enum.max(counts)}
  end

  defp scale_radius(count, min_c, max_c) do
    min_r = 4.0
    max_r = 40.0

    if max_c <= min_c do
      (min_r + max_r) / 2.0
    else
      min_r + (count - min_c) / (max_c - min_c) * (max_r - min_r)
    end
  end

  defp build_grid do
    vlines =
      for lng <- [-150, -90, -30, 30, 90, 150] do
        x = (lng + 180) / 360 * 1000
        %{x1: x, y1: 0.0, x2: x, y2: 500.0}
      end

    hlines =
      for lat <- [-60, -30, 0, 30, 60] do
        y = (90 - lat) / 180 * 500
        %{x1: 0.0, y1: y, x2: 1000.0, y2: y}
      end

    vlines ++ hlines
  end

  defp sum(regions, key) do
    Enum.reduce(regions, 0, fn region, acc -> acc + (region[key] || 0) end)
  end

  # --- Player (network) view ------------------------------------------------

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
      gamer_tag: map["gamer_tag"],
      graph_nodes: layout.nodes,
      graph_edges: layout.edges,
      excluded: excluded,
      opponent_count: length(opponents),
      bubbles: [],
      grid_lines: [],
      region_count: 0,
      total_tournaments: 0,
      total_attendees: 0
    )
  end

  defp assign_empty_player(socket, id) do
    assign(socket,
      view: :player,
      gamer_tag: "Player #{id}",
      graph_nodes: [],
      graph_edges: [],
      excluded: 0,
      opponent_count: 0,
      bubbles: [],
      grid_lines: [],
      region_count: 0,
      total_tournaments: 0,
      total_attendees: 0
    )
  end

  # Place the focal node at the center and fan opponents around a ring; bubble
  # radius scales with the number of shared sets (weight).
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

  # --- Render --------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:atlas}>
      <div id="atlas-live" class="animate-rise">
        <%= if @view == :map do %>
          <div class="mb-8 flex flex-col gap-2">
            <h1 class="font-display text-3xl font-bold tracking-tight text-ink">Atlas</h1>
            <p class="max-w-2xl text-sm text-muted">
              Where the Melee scene shows up. Bubble size reflects the number of tournaments in each region across the 2026 season.
            </p>
          </div>

          <div class="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <.stat label="Regions" value={to_string(@region_count)} />
            <.stat label="Tournaments" value={to_string(@total_tournaments)} />
            <.stat label="Attendees" value={to_string(@total_attendees)} />
            <.stat label="Season" value="2026" />
          </div>

          <%= if Enum.empty?(@bubbles) do %>
            <.empty
              class="mt-6"
              icon="hero-map"
              title="No regions to map yet"
              description="Tournament regions will appear here once the season data loads."
            />
          <% else %>
            <div class="atlas-canvas" id="atlas-map">
              <svg
                class="atlas-svg"
                viewBox="0 0 1000 500"
                role="img"
                aria-label="Tournament region bubble map"
              >
                <%= for line <- @grid_lines do %>
                  <line class="atlas-grid-line" x1={line.x1} y1={line.y1} x2={line.x2} y2={line.y2} />
                <% end %>
                <%= for bubble <- @bubbles do %>
                  <g class="atlas-bubble">
                    <circle class="atlas-bubble-fill" cx={bubble.x} cy={bubble.y} r={bubble.r}>
                      <title>{bubble.label} · {bubble.sub}</title>
                    </circle>
                    <text
                      class="atlas-label"
                      x={bubble.x}
                      y={bubble.y - bubble.r - 4}
                      text-anchor="middle"
                    >
                      {bubble.label}
                    </text>
                  </g>
                <% end %>
              </svg>
            </div>
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
            <div class="atlas-canvas" id="atlas-network">
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
