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
      |> assign(player_a: player_a, player_b: player_b, data: nil, error: nil, loading: true)
      |> spawn_load(player_a, player_b, game)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:compare_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        {:noreply, assign(socket, data: data, error: nil, loading: false, load_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, error: reason, loading: false)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
          Browse
        </.btn>

        <div class="mt-5">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
            Player comparison
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-stone-50">
            {@player_a} vs {@player_b}
          </h1>
        </div>

        <div class="mt-8">
          <%= if @loading do %>
            <div class="grid gap-4 lg:grid-cols-2">
              <.skeleton :for={_ <- 1..4} class="h-40 rounded-xl" />
            </div>
          <% else %>
            <%= if @data == nil do %>
              <.empty_state icon="hero-exclamation-triangle" title="Couldn't compare these players">
                <:body>The start.gg API may be unhappy right now — try again in a moment.</:body>
              </.empty_state>
            <% else %>
              <div id="compare-panel" class="grid gap-4 lg:grid-cols-2">
                <div
                  :for={player <- @data["players"]}
                  class="rounded-xl border border-stone-800 bg-stone-900/40 p-5"
                >
                  <div class="flex items-center justify-between gap-3">
                    <.avatar name={player["gamer_tag"]} class="size-10" />
                    <.link
                      navigate={~p"/player/#{player["player_id"]}"}
                      class="text-lg font-semibold text-stone-100 transition-colors hover:text-lime-300"
                    >
                      {player["gamer_tag"]}
                    </.link>
                    <span class="ml-auto font-mono text-[13px] text-stone-500">
                      {player["wins"]}W-{player["losses"]}L · {percent(player["win_rate"])}
                    </span>
                  </div>

                  <div class="mt-4 grid grid-cols-3 gap-3">
                    <.stat label="Events entered" value={player["events_entered"]} />
                    <.stat label="Best finish" value={best_finish(player["finishes"])} />
                    <.stat label="Sets seen" value={player["sets_seen"]} />
                  </div>

                  <div class="mt-4">
                    <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-stone-500">
                      Top opponents
                    </h3>
                    <div class="mt-2 space-y-1">
                      <div
                        :for={opponent <- player["opponents"]}
                        class="flex items-center justify-between text-sm"
                      >
                        <span class="truncate text-stone-300">
                          {opponent["name"]}
                          <%= if opponent["unresolved"] do %>
                            <span class="text-stone-600">(unresolved)</span>
                          <% end %>
                        </span>
                        <span class="font-mono text-stone-400">
                          {opponent["wins"]}W-{opponent["losses"]}L
                        </span>
                      </div>
                    </div>
                  </div>

                  <div class="mt-4">
                    <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-stone-500">
                      Monthly form
                    </h3>
                    <div class="mt-2 flex items-end gap-1" style="height: 48px">
                      <div
                        :for={bucket <- player["time_buckets"]}
                        class="flex-1 rounded-t bg-lime-400/70"
                        style={"height: #{max(bucket["win_rate"], 4)}%"}
                        title={"#{bucket["month"]}: #{bucket["wins"]}W-#{bucket["losses"]}L"}
                      >
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mt-6 grid gap-4 lg:grid-cols-3">
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Head-to-head
                  </h2>
                  <div class="mt-3 font-mono text-3xl font-semibold tabular-nums">
                    <span class="text-emerald-400">{@data["head_to_head"]["player_a_wins"]}</span>
                    <span class="mx-2 text-stone-600">-</span>
                    <span class="text-rose-400">{@data["head_to_head"]["player_b_wins"]}</span>
                  </div>
                  <p class="mt-1 text-sm text-stone-400">
                    {@data["head_to_head"]["sets"]} sets · {@data["head_to_head"]["unresolved_sets"]} unresolved
                  </p>
                </.card>
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Shared events
                  </h2>
                  <div class="mt-3 font-mono text-3xl font-semibold text-stone-200 tabular-nums">
                    {@data["comparison"]["events_overlap"]}
                  </div>
                  <p class="mt-1 text-sm text-stone-400">tournaments both entered</p>
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
            <% end %>
          <% end %>
        </div>
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
