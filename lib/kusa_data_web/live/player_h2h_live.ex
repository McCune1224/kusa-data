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
        {:noreply,
         assign(socket,
           data: data,
           identities: identities,
           error: nil,
           loading: false,
           load_ref: nil
         )}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, error: reason, loading: false)}
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
            Head-to-head
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-stone-50">
            ){identity_tag(@identities, :a, @player_id)} vs ){identity_tag(
              @identities,
              :b,
              @opponent_id
            )}
          </h1>
        </div>

        <div class="mt-8">
          <%= if @loading do %>
            <div class="grid gap-4 sm:grid-cols-3">
              <.skeleton :for={_ <- 1..3} class="h-32 rounded-xl" />
            </div>
          <% else %>
            <%= if @data == nil do %>
              <.empty_state icon="hero-exclamation-triangle" title="Couldn't load the matchup">
                <:body>The start.gg API may be unhappy right now — try again in a moment.</:body>
              </.empty_state>
            <% else %>
              <div id="h2h-record" class="grid gap-4 sm:grid-cols-3">
                <div class="rounded-xl border border-stone-800 bg-stone-900/50 px-5 py-5">
                  <div class="text-xs font-medium uppercase tracking-[0.12em] text-stone-400">
                    ){identity_tag(@identities, :a, @player_id)}
                  </div>
                  <div class="mt-2 font-mono text-4xl font-semibold text-emerald-400 tabular-nums">
                    {@data["player_a_wins"]}
                  </div>
                  <div class="mt-1 text-sm text-stone-400">wins</div>
                </div>
                <div class="rounded-xl border border-stone-800 bg-stone-900/50 px-5 py-5 text-center">
                  <div class="text-xs font-medium uppercase tracking-[0.12em] text-stone-400">
                    Sets
                  </div>
                  <div class="mt-2 font-mono text-4xl font-semibold text-stone-200 tabular-nums">
                    {@data["sets"]}
                  </div>
                  <div class="mt-1 text-sm text-stone-400">
                    {@data["unresolved_sets"]} unresolved
                  </div>
                </div>
                <div class="rounded-xl border border-stone-800 bg-stone-900/50 px-5 py-5 text-right">
                  <div class="text-xs font-medium uppercase tracking-[0.12em] text-stone-400">
                    ){identity_tag(@identities, :b, @opponent_id)}
                  </div>
                  <div class="mt-2 font-mono text-4xl font-semibold text-rose-400 tabular-nums">
                    {@data["player_b_wins"]}
                  </div>
                  <div class="mt-1 text-sm text-stone-400">wins</div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
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
