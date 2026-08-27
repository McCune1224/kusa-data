defmodule KusaDataWeb.PlayerH2HLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :tournaments,
       player_id: nil,
       opponent_id: nil,
       data: nil,
       identities: %{},
       graph: nil,
       error: nil,
       loading: true
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_id = params["id"]
    opponent_id = params["vs"]
    game = valid_game(params["game"])

    socket =
      socket
      |> assign(
        player_id: player_id,
        opponent_id: opponent_id,
        data: nil,
        identities: %{},
        graph: nil,
        error: nil,
        loading: true
      )
      |> spawn_load(player_id, opponent_id, game)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:h2h_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, identities} ->
        graph =
          build_h2h_graph(socket.assigns.player_id, socket.assigns.opponent_id, identities, data)

        socket =
          assign(socket,
            data: data,
            identities: identities,
            graph: graph,
            error: nil,
            loading: false,
            load_ref: nil
          )

        {:noreply, push_event(socket, "atlas:data", %{type: "network", graph: graph})}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, graph: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:h2h_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket, player_id, opponent_id, game) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      result =
        with {:ok, data, _} <- Players.head_to_head(player_id, opponent_id, %{game: game}),
             {:ok, a, _} <- Players.profile(player_id),
             {:ok, b, _} <- Players.profile(opponent_id) do
          {:ok, data, %{a: a, b: b}}
        else
          {:error, reason} -> {:error, reason}
          other -> {:error, other}
        end

      send(parent, {:h2h_loaded, ref, result})
    end)

    assign(socket, load_ref: ref)
  end

  defp build_h2h_graph(player_id, opponent_id, identities, data) do
    tag_a = identity_tag(identities, :a, player_id)
    tag_b = identity_tag(identities, :b, opponent_id)
    sets = (data && data["sets"]) || 0
    weight = max(sets, 1)

    nodes = [
      %{
        "player_id" => to_int(player_id),
        "gamer_tag" => tag_a,
        "is_focal" => true,
        "weight" => ((data && data["player_a_wins"]) || 0) + 1
      },
      %{
        "player_id" => to_int(opponent_id),
        "gamer_tag" => tag_b,
        "is_focal" => false,
        "weight" => ((data && data["player_b_wins"]) || 0) + 1
      }
    ]

    edge = %{
      "source" => to_int(player_id),
      "target" => to_int(opponent_id),
      "weight" => weight
    }

    %{"nodes" => nodes, "edges" => [edge]}
  end

  defp to_int(id) when is_integer(id), do: id

  defp to_int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> id
    end
  end

  defp to_int(id), do: id

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

        <div class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)] p-6">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
            Head-to-head
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[var(--text)]">
            {identity_tag(@identities, :a, @player_id)} vs {identity_tag(
              @identities,
              :b,
              @opponent_id
            )}
          </h1>
          <p class="mt-1 text-sm text-[var(--muted)]">Bento duel view with central edge graph</p>
        </div>

        <%= if @loading do %>
          <div class="grid gap-3 sm:grid-cols-3">
            <.skeleton :for={_ <- 1..3} class="h-28 rounded-[20px]" />
          </div>
          <.skeleton class="h-[320px] rounded-[20px]" />
        <% else %>
          <%= if @data == nil do %>
            <.empty_state icon="hero-exclamation-triangle" title="Couldn't load the matchup">
              <:body>The start.gg API may be unhappy right now — try again in a moment.</:body>
            </.empty_state>
          <% else %>
            <div class="grid gap-3 lg:grid-cols-[1fr_auto_1fr]">
              <.card class="p-6 text-center">
                <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-[var(--surface2)] ring-1 ring-[var(--border)]">
                  <.avatar name={identity_tag(@identities, :a, @player_id)} class="size-10" />
                </div>
                <div class="mt-3 text-xs font-medium uppercase tracking-[0.14em] text-[var(--muted)]">
                  {identity_tag(@identities, :a, @player_id)}
                </div>
                <div class="mt-2 font-mono text-4xl font-semibold text-emerald-400 tabular-nums">
                  {@data["player_a_wins"]}
                </div>
                <div class="mt-1 text-sm text-[var(--muted)]">wins</div>
                <.link
                  navigate={~p"/player/#{@player_id}"}
                  class="mt-3 inline-flex rounded-full border border-[var(--border)] bg-[var(--surface2)] px-3 py-1 text-xs text-[var(--muted)] hover:border-[var(--border2)] hover:text-[var(--text)]"
                >
                  View profile
                </.link>
              </.card>

              <div class="flex flex-col items-center justify-center gap-2 py-2 lg:px-2">
                <span class="rounded-full bg-[var(--accent)] px-3 py-1 text-xs font-black uppercase tracking-widest text-[#08070b]">VS</span>
                <span class="font-mono text-xs text-[var(--muted)]">{@data["sets"]} sets</span>
                <span class="text-xs text-[var(--muted)]">{@data["unresolved_sets"]} unresolved</span>
              </div>

              <.card class="p-6 text-center">
                <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-[var(--surface2)] ring-1 ring-[var(--border)]">
                  <.avatar name={identity_tag(@identities, :b, @opponent_id)} class="size-10" />
                </div>
                <div class="mt-3 text-xs font-medium uppercase tracking-[0.14em] text-[var(--muted)]">
                  {identity_tag(@identities, :b, @opponent_id)}
                </div>
                <div class="mt-2 font-mono text-4xl font-semibold text-rose-400 tabular-nums">
                  {@data["player_b_wins"]}
                </div>
                <div class="mt-1 text-sm text-[var(--muted)]">wins</div>
                <.link
                  navigate={~p"/player/#{@opponent_id}"}
                  class="mt-3 inline-flex rounded-full border border-[var(--border)] bg-[var(--surface2)] px-3 py-1 text-xs text-[var(--muted)] hover:border-[var(--border2)] hover:text-[var(--text)]"
                >
                  View profile
                </.link>
              </.card>
            </div>

            <div class="grid gap-3 lg:grid-cols-[1.4fr_0.6fr]">
              <.card class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                    Edge graph
                  </h2>
                  <span class="font-mono text-[11px] text-[var(--muted)]">H2H network · {length(
                    (@graph && @graph["edges"]) || []
                  )} edge</span>
                </div>
                <div
                  id="player-network"
                  phx-hook="AtlasHook"
                  phx-update="ignore"
                  class="atlas-canvas mt-4 h-[320px] w-full overflow-hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40"
                >
                </div>
                <p class="mt-3 text-xs text-[var(--muted)]">
                  Central edge visualizes the duel. Nodes scale with wins.
                </p>
              </.card>

              <.card class="p-5">
                <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                  Record
                </h2>
                <div id="h2h-record" class="mt-4 space-y-3">
                  <div class="flex items-center justify-between rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40 px-4 py-4">
                    <span class="text-sm text-[var(--muted)]">Sets played</span>
                    <span class="font-mono text-lg font-semibold text-[var(--text)]">{@data["sets"]}</span>
                  </div>
                  <div class="flex items-center justify-between rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40 px-4 py-4">
                    <span class="text-sm text-[var(--muted)]">Unresolved</span>
                    <span class="font-mono text-lg font-semibold text-amber-300">{@data[
                      "unresolved_sets"
                    ]}</span>
                  </div>
                  <div class="rounded-[16px] bg-[var(--accent)]/10 px-4 py-3 ring-1 ring-[var(--accent)]/20">
                    <p class="text-xs font-semibold uppercase tracking-widest text-[var(--accent)]">
                      Outcome
                    </p>
                    <p class="mt-1 font-mono text-sm text-[var(--text)]">
                      <%= cond do %>
                        <% @data["player_a_wins"] > @data["player_b_wins"] -> %>
                          {identity_tag(@identities, :a, @player_id)} leads
                        <% @data["player_b_wins"] > @data["player_a_wins"] -> %>
                          {identity_tag(@identities, :b, @opponent_id)} leads
                        <% true -> %>
                          Even
                      <% end %>
                      · {@data["player_a_wins"]}-{@data["player_b_wins"]}
                    </p>
                  </div>
                </div>
              </.card>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp identity_tag(identities, key, fallback) do
    case Map.get(identities, key) do
      %{"gamer_tag" => tag} -> tag
      _ -> "Player #{fallback}"
    end
  end

  defp valid_game(nil), do: nil

  defp valid_game(slug) do
    case Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> nil
    end
  end
end
