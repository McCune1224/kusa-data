defmodule KusaDataWeb.GameLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :tournaments,
       game: nil,
       not_found: false,
       total: 0,
       next_page: nil,
       error: nil,
       loading: true,
       page: 1
     )
     |> stream_configure(:tournaments, dom_id: fn t -> "tournament-#{t["id"]}" end)
     |> stream(:tournaments, [])}
  end

  @impl true
  def handle_params(%{"game" => slug}, _uri, socket) do
    case Games.by_slug(slug) do
      nil ->
        {:noreply,
         assign(socket,
           game: nil,
           not_found: true,
           loading: false,
           total: 0,
           next_page: nil
         )}

      game ->
        socket =
          socket
          |> assign(
            game: game,
            not_found: false,
            loading: true,
            page: 1,
            next_page: nil
          )
          |> spawn_load(1, true)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:load_result, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    page = socket.assigns.page
    reset = socket.assigns.reset

    socket =
      case result do
        {:ok, data, _status} ->
          socket
          |> assign(error: nil, loading: false)
          |> assign(total: data["total"], next_page: next_page(page, data["total"]))
          |> stream(:tournaments, data["tournaments"], reset: reset)

        {:error, reason} ->
          socket
          |> assign(total: 0, next_page: nil, error: reason, loading: false)
          |> stream(:tournaments, [], reset: true)
      end

    {:noreply, assign(socket, load_ref: nil)}
  end

  def handle_info({:load_result, _ref, _result}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("load-more", _params, socket) do
    page = socket.assigns.next_page

    if page && socket.assigns.game do
      {:noreply, spawn_load(socket, page, false)}
    else
      {:noreply, socket}
    end
  end

  defp spawn_load(socket, page, reset) do
    ref = make_ref()
    parent = self()
    query = %{mode: :upcoming, games: [socket.assigns.game.slug], page: page}

    Task.start(fn ->
      send(parent, {:load_result, ref, Tournaments.browse(query)})
    end)

    assign(socket, load_ref: ref, page: page, reset: reset)
  end

  defp next_page(page, total) do
    if page * 24 < total, do: page + 1, else: nil
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="desk-grid animate-fade-up">
        <div class="mb-5 flex items-center justify-between border-y border-stone-800 py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-stone-500">
          <span><span class="mr-2 inline-block size-2 bg-lime-400"></span>Live bracket index</span>
          <span class="hidden sm:inline">Games</span>
          <span class="text-orange-300">03 — Games</span>
        </div>

        <%= if @not_found do %>
          <section class="mt-10">
            <.empty_state icon="hero-question-mark-circle" title="No such game">
              <:body>
                That game slug is not in the registry. It may not be a supported start.gg
                videogame yet.
              </:body>
              <:action>
                <.btn variant="primary" navigate={~p"/"}>Back to browsing</.btn>
              </:action>
            </.empty_state>
          </section>
        <% else %>
          <section>
            <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
              All tournaments
            </.btn>
            <p class="mt-4 text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              Game page
            </p>
            <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-stone-50 sm:text-5xl">
              {@game[:name]}
            </h1>
            <p class="mt-2 text-[15px] text-stone-400">
              Upcoming {@game[:short_name]} tournaments · {format_count(@total)}
            </p>
          </section>

          <section class="mt-10">
            <TournamentGrid.tournament_grid
              tournaments={@streams.tournaments}
              total={@total}
              loading={@loading}
              error={@error}
              empty_title="No upcoming tournaments"
              empty_body=" for this game yet"
              reset_link={~p"/"}
              reset_label="All tournaments"
              next_page={@next_page}
            />
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_count(0), do: "No events"
  defp format_count(1), do: "1 event"
  defp format_count(total), do: "#{total} events"
end
