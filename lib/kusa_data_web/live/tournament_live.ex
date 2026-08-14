defmodule KusaDataWeb.TournamentLive do
  use KusaDataWeb, :live_view

  alias KusaData.Tournaments

  @videogame_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tournament, nil)
     |> assign(:slug, nil)
     |> assign(:finder_state, :idle)
     |> assign(:finder_error, nil)
     |> assign(:finder_tournament, nil)
     |> assign(:finder_events, [])
     |> assign(:seeding_event, nil)
     |> assign(:seeding_entrants, [])}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    tournament =
      case Tournaments.get_by_slug(slug) do
        nil -> nil
        t -> Tournaments.roster(t)
      end

    {:noreply,
     socket
     |> assign(:slug, slug)
     |> assign(:tournament, tournament)
     |> assign(:page_title, (tournament && "Tournament") || "Tournament not found")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:page_title, "Seed finder")}
  end

  @impl true
  def handle_event("find_seeds", %{"url" => url}, socket) do
    case Tournaments.Url.normalize(url) do
      nil ->
        {:noreply,
         socket
         |> assign(:finder_state, :error)
         |> assign(:finder_error, "Enter a valid start.gg tournament or event URL.")
         |> assign(:finder_events, [])
         |> assign(:seeding_entrants, [])}

      %{tournament_slug: slug, event_slug: event_slug} ->
        {:noreply, load_finder(socket, slug, event_slug)}
    end
  end

  @impl true
  def handle_event("pick_event", %{"event_id" => event_id}, socket) do
    case Enum.find(socket.assigns.finder_events, &(to_string(&1.id) == event_id)) do
      nil -> {:noreply, socket}
      event -> {:noreply, load_seeding(socket, event)}
    end
  end

  defp load_finder(socket, slug, event_slug) do
    case Tournaments.API.events("tournament/" <> slug, @videogame_id) do
      {:ok, tournament} ->
        socket =
          socket
          |> assign(:finder_state, :events)
          |> assign(:finder_error, nil)
          |> assign(:finder_tournament, tournament)
          |> assign(:finder_events, tournament.events)
          |> assign(:seeding_entrants, [])

        case resolve_event(tournament.events, event_slug) do
          nil -> socket
          event -> load_seeding(socket, event)
        end

      {:error, _reason} ->
        socket
        |> assign(:finder_state, :error)
        |> assign(
          :finder_error,
          "Couldn't load this tournament from start.gg — try again shortly."
        )
        |> assign(:finder_events, [])
        |> assign(:seeding_entrants, [])
    end
  end

  defp resolve_event(_events, nil), do: nil

  defp resolve_event(events, event_slug) do
    Enum.find(events, &String.ends_with?(&1.slug || "", event_slug))
  end

  defp load_seeding(socket, event) do
    case Tournaments.API.seeding(event.id) do
      {:ok, seeding} ->
        socket
        |> assign(:seeding_event, %{id: seeding.id, name: seeding.name})
        |> assign(:seeding_entrants, seeding.entrants)

      {:error, _reason} ->
        socket
        |> assign(:finder_state, :error)
        |> assign(:finder_error, "Couldn't load seeding for this event.")
        |> assign(:seeding_entrants, [])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tournament-page" class="flex flex-col gap-10">
      <%= if @slug do %>
        <section class="flex flex-col gap-3">
          <h1 class="text-3xl font-bold tracking-tight text-ink">
            {if @tournament, do: "Tournament · #{@slug}", else: "Tournament"}
          </h1>

          <%= if @tournament == nil do %>
            <.empty_state
              title="Tournament not crawled"
              hint="Only tournaments inside the rankings crawl window have rosters here."
            />
          <% else %>
            <%= for event <- @tournament.events do %>
              <div class="flex flex-col gap-3">
                <h2 class="text-xl font-semibold text-ink">{event.name}</h2>

                <%= if event.entrants == [] do %>
                  <.empty_state title="No entrants recorded" hint="This event wasn't ingested yet." />
                <% else %>
                  <.table id={"roster-#{event.id}"}>
                    <:head>
                      <th class="p-3 text-left">Placement</th>
                      <th class="p-3 text-left">Player</th>
                    </:head>

                    <tr :for={entrant <- Tournaments.standings(event)}>
                      <td class="p-3 font-mono text-ink-muted">{entrant.standing || "—"}</td>
                      <td class="p-3">
                        <%= if entrant.player do %>
                          <.link
                            href={~p"/players/#{entrant.player.id}"}
                            class="font-medium text-ink hover:text-accent"
                          >
                            {if entrant.player.prefix, do: "#{entrant.player.prefix} | "}{entrant.player.gamer_tag}
                          </.link>
                        <% else %>
                          <span class="text-ink-faint">Unknown player</span>
                        <% end %>
                      </td>
                    </tr>
                  </.table>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </section>
      <% end %>

      <section id="seed-finder" class="flex flex-col gap-3">
        <div>
          <h2 class="text-2xl font-semibold text-ink">Seed finder</h2>
          <p class="mt-1 text-ink-muted">
            Paste a start.gg tournament or event URL to see every entrant's seed.
          </p>
        </div>

        <form id="seed-finder-form" phx-submit="find_seeds" class="flex flex-wrap gap-2" role="search">
          <label for="seed-finder-url" class="sr-only">start.gg URL</label>
          <input
            type="url"
            id="seed-finder-url"
            name="url"
            placeholder="https://start.gg/tournament/…"
            autocomplete="off"
            class="min-w-64 flex-1 rounded-md border border-line bg-card px-3 py-2 text-sm text-ink placeholder:text-ink-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20"
          />
          <button
            type="submit"
            class="inline-flex min-h-11 items-center rounded-md bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-strong"
          >
            Find seeds
          </button>
        </form>

        <%= if @finder_error do %>
          <.empty_state title="Couldn't load" hint={@finder_error} />
        <% end %>

        <%= if @finder_events != [] do %>
          <div class="flex flex-col gap-2">
            <p class="text-sm font-semibold text-ink-muted">
              {(@finder_tournament && @finder_tournament.name) || "Events"} — pick a bracket:
            </p>

            <div class="flex flex-wrap gap-2">
              <button
                :for={event <- @finder_events}
                type="button"
                phx-click="pick_event"
                phx-value-event_id={event.id}
                class="inline-flex min-h-11 items-center rounded-md border border-line-strong bg-card px-4 py-2 text-sm font-medium text-ink transition-colors hover:bg-paper-soft"
              >
                {event.name}
              </button>
            </div>
          </div>
        <% end %>

        <%= if @seeding_entrants != [] do %>
          <div class="flex flex-col gap-2">
            <h3 class="text-lg font-semibold text-ink">
              Seeding · {@seeding_event.name}
            </h3>

            <.table id="seeding-table">
              <:head>
                <th class="p-3 text-left">Seed</th>
                <th class="p-3 text-left">Entrant</th>
              </:head>

              <tr :for={entrant <- @seeding_entrants}>
                <td class="p-3 font-mono text-ink-muted">
                  {Enum.join(entrant.seed_nums, ", ") || "—"}
                </td>
                <td class="p-3 font-medium text-ink">{entrant.name}</td>
              </tr>
            </.table>
          </div>
        <% end %>
      </section>
    </div>
    """
  end
end
