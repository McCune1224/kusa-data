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
      |> assign(player_id: player_id, data: nil, error: nil, loading: true)
      |> spawn_load(player_id, game)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trend_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        {:noreply, assign(socket, data: data, error: nil, loading: false, load_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, error: reason, loading: false)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <.btn
          variant="ghost"
          size="sm"
          icon="hero-arrow-left"
          navigate={~p"/player/#{@player_id}"}
        >
          Player page
        </.btn>

        <div class="mt-5">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
            Player trend
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-stone-50">
            {if @data, do: @data["gamer_tag"], else: "Player #{@player_id}"}
          </h1>
          <p class="mt-1 text-[15px] text-stone-400">
            Monthly win rate and best placement{game_suffix(@game)}
          </p>
        </div>

        <div class="mt-8">
          <%= if @loading do %>
            <div class="space-y-3">
              <.skeleton :for={_ <- 1..6} class="h-16 w-full rounded-none" />
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
                  class="flex items-center gap-4 rounded-xl border border-stone-800 bg-stone-900/40 px-5 py-4"
                >
                  <span class="w-16 shrink-0 font-mono text-sm text-stone-400">
                    {bucket["month"]}
                  </span>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center justify-between text-xs text-stone-500">
                      <span>{bucket["wins"]}W-{bucket["losses"]}L</span>
                      <span>{percent(bucket["win_rate"])}</span>
                    </div>
                    <div class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-stone-800">
                      <div
                        class="h-full rounded-full bg-lime-400 transition-all duration-300"
                        style={"width: #{min(bucket["win_rate"], 100)}%"}
                      >
                      </div>
                    </div>
                  </div>
                  <span class="w-24 shrink-0 text-right font-mono text-sm">
                    <%= if bucket["best_placement"] do %>
                      <span class="text-stone-300">best #{ordinal(bucket["best_placement"])}</span>
                    <% else %>
                      <span class="text-stone-600">no placement</span>
                    <% end %>
                  </span>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
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
