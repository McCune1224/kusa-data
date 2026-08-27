defmodule KusaDataWeb.CompareLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :tournaments,
       player_a: nil,
       player_b: nil,
       data: nil,
       graph: nil,
       error: nil,
       loading: true
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_a = params["a"]
    player_b = params["b"]
    game = valid_game(params["game"])

    socket =
      socket
      |> assign(
        player_a: player_a,
        player_b: player_b,
        data: nil,
        graph: nil,
        error: nil,
        loading: true
      )
      |> spawn_load(player_a, player_b, game)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:compare_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        graph = build_compare_graph(data)

        socket =
          assign(socket, data: data, graph: graph, error: nil, loading: false, load_ref: nil)

        {:noreply, push_event(socket, "atlas:data", %{type: "network", graph: graph})}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, graph: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:compare_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket, player_a, player_b, game) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:compare_loaded, ref, Players.compare(player_a, player_b, %{game: game})})
    end)

    assign(socket, load_ref: ref)
  end

  defp build_compare_graph(data) do
    players = data["players"] || []

    base_nodes =
      Enum.map(players, fn p ->
        %{
          "player_id" => p["player_id"],
          "gamer_tag" => p["gamer_tag"],
          "is_focal" => true,
          "weight" => max((p["wins"] || 0) + (p["losses"] || 0), 1)
        }
      end)

    h2h = data["head_to_head"] || %{}
    shared_ids = MapSet.new()

    opponent_nodes =
      players
      |> Enum.flat_map(fn p -> p["opponents"] || [] end)
      |> Enum.uniq_by(& &1["opponent_player_id"])
      |> Enum.reject(fn o -> is_nil(o["opponent_player_id"]) end)
      |> Enum.take(12)
      |> Enum.map(fn o ->
        %{
          "player_id" => o["opponent_player_id"],
          "gamer_tag" => o["name"],
          "is_focal" => false,
          "weight" => o["total"] || 1
        }
      end)

    nodes = base_nodes ++ opponent_nodes

    h2h_edge =
      case base_nodes do
        [a, b] ->
          [
            %{
              "source" => a["player_id"],
              "target" => b["player_id"],
              "weight" => max(h2h["sets"] || 1, 1)
            }
          ]

        _ ->
          []
      end

    opp_edges =
      Enum.flat_map(players, fn p ->
        Enum.flat_map(p["opponents"] || [], fn opp ->
          case opp["opponent_player_id"] do
            nil ->
              []

            opp_id ->
              [%{"source" => p["player_id"], "target" => opp_id, "weight" => opp["total"] || 1}]
          end
        end)
      end)
      |> Enum.take(16)

    edges = h2h_edge ++ opp_edges

    # Ensure at least focal nodes
    nodes =
      if nodes == [] do
        [
          %{"player_id" => 1, "gamer_tag" => "Player A", "is_focal" => true, "weight" => 1},
          %{"player_id" => 2, "gamer_tag" => "Player B", "is_focal" => true, "weight" => 1}
        ]
      else
        nodes
      end

    _ = shared_ids

    %{"nodes" => nodes, "edges" => edges}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="space-y-4 animate-fade-up">
        <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
          Browse
        </.btn>

        <.card class="p-6">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
            Player comparison
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[var(--text)]">
            {@player_a} vs {@player_b}
          </h1>
          <p class="mt-1 text-sm text-[var(--muted)]">Side-by-side bento with shared ego-network</p>
        </.card>

        <%= if @loading do %>
          <div class="grid gap-3 lg:grid-cols-2">
            <.skeleton :for={_ <- 1..2} class="h-64 rounded-[20px]" />
          </div>
          <.skeleton class="h-[320px] rounded-[20px]" />
        <% else %>
          <%= if @data == nil do %>
            <.empty_state icon="hero-exclamation-triangle" title="Couldn't compare these players">
              <:body>The start.gg API may be unhappy right now — try again in a moment.</:body>
            </.empty_state>
          <% else %>
            <div id="compare-panel" class="grid gap-3 lg:grid-cols-2">
              <div
                :for={player <- @data["players"]}
                class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)] p-5"
              >
                <div class="flex items-center justify-between gap-3">
                  <.avatar name={player["gamer_tag"]} class="size-10" />
                  <.link
                    navigate={~p"/player/#{player["player_id"]}"}
                    class="text-lg font-semibold text-[var(--text)] transition-colors hover:text-[var(--accent)]"
                  >
                    {player["gamer_tag"]}
                  </.link>
                  <span class="ml-auto rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2.5 py-1 font-mono text-[13px] text-[var(--muted)]">
                    {player["wins"]}W-{player["losses"]}L · {percent(player["win_rate"])}
                  </span>
                </div>

                <div class="mt-4 grid grid-cols-3 gap-3">
                  <.stat label="Events entered" value={player["events_entered"]} />
                  <.stat label="Best finish" value={best_finish(player["finishes"])} />
                  <.stat label="Sets seen" value={player["sets_seen"]} />
                </div>

                <div class="mt-4">
                  <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-[var(--muted)]">
                    Top opponents
                  </h3>
                  <div class="mt-2 space-y-1">
                    <div
                      :for={opponent <- player["opponents"]}
                      class="flex items-center justify-between rounded-[12px] border border-transparent px-2 py-1.5 text-sm hover:border-[var(--border)] hover:bg-[var(--surface2)]/40"
                    >
                      <span class="truncate text-[var(--text)]">
                        {opponent["name"]}
                        <%= if opponent["unresolved"] do %>
                          <span class="text-[var(--muted)]">(unresolved)</span>
                        <% end %>
                      </span>
                      <span class="font-mono text-[var(--muted)]">
                        {opponent["wins"]}W-{opponent["losses"]}L
                      </span>
                    </div>
                  </div>
                </div>

                <div class="mt-4">
                  <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-[var(--muted)]">
                    Monthly form
                  </h3>
                  <div class="mt-2 flex items-end gap-1" style="height: 48px">
                    <div
                      :for={bucket <- player["time_buckets"]}
                      class="flex-1 rounded-t bg-[var(--accent)]/70"
                      style={"height: #{max(bucket["win_rate"], 4)}%"}
                      title={"#{bucket["month"]}: #{bucket["wins"]}W-#{bucket["losses"]}L"}
                    >
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="grid gap-3 lg:grid-cols-[1.2fr_0.8fr]">
              <.card class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Shared graph
                  </h2>
                  <span class="font-mono text-[11px] text-[var(--muted)]">combined ego-network</span>
                </div>
                <div
                  id="player-network"
                  phx-hook="AtlasHook"
                  phx-update="ignore"
                  class="atlas-canvas mt-4 h-[360px] w-full overflow-hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40"
                >
                </div>
                <p class="mt-3 text-xs text-[var(--muted)]">
                  Focal players in accent · edges weight sets · tap node to inspect
                </p>
              </.card>

              <div class="space-y-3">
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Head-to-head
                  </h2>
                  <div class="mt-3 font-mono text-3xl font-semibold tabular-nums">
                    <span class="text-emerald-400">{@data["head_to_head"]["player_a_wins"]}</span>
                    <span class="mx-2 text-[var(--muted)]">-</span>
                    <span class="text-rose-400">{@data["head_to_head"]["player_b_wins"]}</span>
                  </div>
                  <p class="mt-1 text-sm text-[var(--muted)]">
                    {@data["head_to_head"]["sets"]} sets · {@data["head_to_head"]["unresolved_sets"]} unresolved
                  </p>
                </.card>
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Shared events
                  </h2>
                  <div class="mt-3 font-mono text-3xl font-semibold text-[var(--text)] tabular-nums">
                    {@data["comparison"]["events_overlap"]}
                  </div>
                  <p class="mt-1 text-sm text-[var(--muted)]">tournaments both entered</p>
                </.card>
                <.card class="p-5 flex flex-col justify-center">
                  <.btn
                    variant="secondary"
                    size="sm"
                    navigate={
                      ~p"/player/#{@data["players"] |> hd() |> Map.get("player_id")}/h2h?vs=#{@data["players"] |> List.last() |> Map.get("player_id")}"
                    }
                  >
                    Full H2H page
                  </.btn>
                </.card>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp best_finish([]), do: "—"

  defp best_finish(finishes) do
    finishes |> Enum.map(& &1["placement"]) |> Enum.min() |> then(fn p -> "##{p}" end)
  end

  defp valid_game(nil), do: nil

  defp valid_game(slug) do
    case Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> nil
    end
  end
end
