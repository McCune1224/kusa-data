defmodule KusaDataWeb.RegionLive do
  use KusaDataWeb, :live_view

  alias KusaData.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :tournaments,
       view: :index,
       country: nil,
       state: nil,
       regions: [],
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
  def handle_params(%{"country" => country, "state" => state}, _uri, socket) do
    socket =
      socket
      |> assign(
        view: :listing,
        country: country,
        state: state,
        loading: true,
        page: 1,
        next_page: nil
      )
      |> spawn_listing(country, state, 1, true)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    socket = socket |> assign(view: :index, loading: true) |> spawn_index()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:regions_loaded, ref, result}, %{assigns: %{regions_ref: ref}} = socket) do
    case result do
      {:ok, regions, _status} ->
        {:noreply, assign(socket, regions: regions, error: nil, loading: false, regions_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, regions: [], error: reason, loading: false, regions_ref: nil)}
    end
  end

  def handle_info({:regions_loaded, _ref, _result}, socket), do: {:noreply, socket}

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

    if page && socket.assigns.country do
      {:noreply, spawn_listing(socket, socket.assigns.country, socket.assigns.state, page, false)}
    else
      {:noreply, socket}
    end
  end

  defp spawn_index(socket) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:regions_loaded, ref, Tournaments.regions()})
    end)

    assign(socket, regions_ref: ref)
  end

  defp spawn_listing(socket, country, state, page, reset) do
    ref = make_ref()
    parent = self()
    query = %{mode: :region, country: country, state: state, page: page}

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
          <span class="hidden sm:inline">Regions</span>
          <span class="text-orange-300">02 — Regions</span>
        </div>

        <section>
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-lime-300">
            Browse by region
          </p>
          <div class="mt-2 flex flex-wrap items-end justify-between gap-4">
            <h1 class="text-4xl font-black uppercase tracking-[-0.05em] text-stone-50 sm:text-5xl">
              <%= if @view == :listing do %>
                {@country}{if @state, do: " / #{@state}"}
              <% else %>
                Where it happens
              <% end %>
            </h1>
            <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
              All tournaments
            </.btn>
          </div>
        </section>

        <%= if @view == :index do %>
          <section class="mt-10">
            <%= if @loading do %>
              <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <.skeleton :for={_ <- 1..9} class="h-24 rounded-none" />
              </div>
            <% else %>
              <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <div
                  :for={region <- @regions}
                  class="flex flex-col justify-between border border-stone-800 bg-stone-900/40 p-5 transition-colors hover:border-stone-600 hover:bg-stone-900/70"
                >
                  <.link
                    navigate={region_path(region)}
                    class="group"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div class="min-w-0">
                        <h3 class="truncate text-lg font-medium text-stone-200 group-hover:text-stone-50">
                          {region_label(region)}
                        </h3>
                        <p class="mt-1 text-sm text-stone-400">
                          {region["tournaments"]} tournament{plural(region["tournaments"])} · {region[
                            "attendees"
                          ]} attendees
                        </p>
                      </div>
                      <.icon
                        name="hero-arrow-right"
                        class="size-4 shrink-0 text-stone-600 group-hover:text-lime-300"
                      />
                    </div>
                  </.link>
                </div>
              </div>

              <div :if={@regions == []} class="mt-8">
                <.empty_state icon="hero-globe-americas" title="No regions available">
                  <:body>The start.gg API may be unhappy right now — try again in a moment.</:body>
                  <:action>
                    <.btn variant="secondary" navigate={~p"/"} class="rounded-none">
                      Back to browsing
                    </.btn>
                  </:action>
                </.empty_state>
              </div>
            <% end %>
          </section>
        <% else %>
          <section class="mt-10">
            <div class="flex flex-wrap items-end justify-between gap-4">
              <div>
                <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                  upcoming in {@country}{if @state, do: " / #{@state}", else: ""}
                </p>
                <h2 class="mt-2 text-2xl font-semibold tracking-tight text-stone-100">
                  Tournaments
                </h2>
                <p class="mt-1 text-[15px] text-stone-400">{format_count(@total)}</p>
              </div>
            </div>

            <TournamentGrid.tournament_grid
              tournaments={@streams.tournaments}
              total={@total}
              loading={@loading}
              error={@error}
              empty_title="No upcoming tournaments here"
              empty_body=" — check back closer to the season"
              reset_link={~p"/regions"}
              reset_label="All regions"
              next_page={@next_page}
            />
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp region_label(%{"state" => state, "country" => country}) when is_binary(state),
    do: "#{country}, #{state}"

  defp region_label(%{"country" => country}), do: country

  defp region_path(%{"state" => state, "country" => country}) when is_binary(state) do
    "/region/#{URI.encode_www_form(country)}/#{URI.encode_www_form(state)}"
  end

  defp region_path(%{"country" => country}) do
    "/region/#{URI.encode_www_form(country)}"
  end

  defp format_count(0), do: "No events"
  defp format_count(1), do: "1 event"
  defp format_count(total), do: "#{total} events"

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
