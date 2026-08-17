defmodule KusaDataWeb.TournamentLive do
  use KusaDataWeb, :live_view

  alias KusaData.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       tournament: nil,
       error: nil,
       loading: true,
       slug: nil,
       nav: :tournaments
     )
     |> stream_configure(:events, dom_id: fn e -> "event-#{e["id"]}" end)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    slug = slug |> String.trim() |> bare_slug()

    socket = assign(socket, tournament: nil, error: nil, loading: true, slug: slug)
    socket = spawn_load(socket, slug)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_result, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, tournament, _status} ->
        {:noreply,
         socket
         |> assign(tournament: tournament, error: nil, loading: false, load_ref: nil)
         |> stream(:events, tournament["events"] || [], reset: true)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(tournament: nil, error: reason, loading: false, load_ref: nil)
         |> stream(:events, [], reset: true)}
    end
  end

  def handle_info({:load_result, _ref, _result}, socket) do
    {:noreply, socket}
  end

  defp spawn_load(socket, slug) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:load_result, ref, Tournaments.by_slug(slug)})
    end)

    assign(socket, load_ref: ref)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav}>
      <div>
        <%= cond do %>
          <% @loading -> %>
            <div class="space-y-10">
              <div>
                <.skeleton class="h-3 w-24" />
                <div class="mt-4 space-y-3">
                  <.skeleton class="h-9 w-3/4 sm:w-1/2" />
                  <.skeleton class="h-4 w-2/3 sm:w-1/3" />
                  <.skeleton class="h-4 w-1/2 sm:w-1/4" />
                </div>
              </div>

              <div>
                <div class="flex items-center justify-between gap-3">
                  <.skeleton class="h-6 w-40" />
                  <.skeleton class="h-4 w-10" />
                </div>
                <div class="mt-4 rounded-xl border border-stone-800/80">
                  <.skeleton
                    :for={_ <- 1..5}
                    class="h-14 w-full rounded-none border-b border-stone-800/60 last:border-b-0"
                  />
                </div>
              </div>
            </div>
          <% @tournament -> %>
            <section>
              <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
                All tournaments
              </.btn>
              <p class="mt-4 text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                Tournament
              </p>
              <h1 class="mt-2 text-3xl font-semibold tracking-tight text-stone-50">
                {@tournament["name"]}
              </h1>

              <div class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2">
                <span class="inline-flex items-center gap-1.5">
                  <.icon name="hero-map-pin" class="size-4 text-stone-600" />
                  <span class="text-[15px] text-stone-400">{location_label(@tournament)}</span>
                </span>
                <span class="inline-flex items-center gap-1.5">
                  <.icon name="hero-calendar-days" class="size-4 text-stone-600" />
                  <span class="text-[15px] text-stone-400">{date_range(@tournament)}</span>
                </span>
                <%= if venue_label(@tournament) != "—" do %>
                  <span class="inline-flex items-center gap-1.5">
                    <.icon name="hero-building-office" class="size-4 text-stone-600" />
                    <span class="text-[15px] text-stone-400">{venue_label(@tournament)}</span>
                  </span>
                <% end %>
                <a
                  href={"https://www.start.gg/#{@tournament["slug"]}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1.5 text-[15px] text-stone-400 transition-colors hover:text-stone-100"
                >
                  <.icon name="hero-arrow-top-right-on-square" class="size-4" /> start.gg
                </a>
              </div>

              <%= if format_entrants(@tournament) != "—" do %>
                <p class="mt-3 font-mono text-[13px] text-stone-400">
                  {format_entrants(@tournament)}
                </p>
              <% end %>
            </section>

            <section class="mt-10">
              <div class="flex flex-wrap items-baseline justify-between gap-3">
                <h2 class="text-lg font-semibold tracking-tight text-stone-100">Melee events</h2>
                <span class="font-mono text-[13px] text-stone-400">
                  {length(@tournament["events"] || [])}
                </span>
              </div>

              <div
                id="events"
                phx-update="stream"
                class="mt-4 rounded-xl border border-stone-800/80"
              >
                <div
                  id="events-empty"
                  class="hidden px-6 py-10 text-center text-[15px] text-stone-400 only:block"
                >
                  No Melee events on this tournament page.
                </div>

                <div
                  :for={{id, ev} <- @streams.events}
                  id={id}
                  class="flex flex-col gap-2 border-b border-stone-800/70 px-5 py-4 transition-colors last:border-b-0 hover:bg-stone-900/60 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
                >
                  <div class="min-w-0">
                    <div class="truncate text-[15px] font-medium text-stone-200">{ev["name"]}</div>
                    <div class="mt-1 text-sm text-stone-400">
                      {ev["numEntrants"] || 0} entrants · {state_label(ev["state"])}
                    </div>
                  </div>
                  <div class="flex shrink-0 gap-1">
                    <.btn
                      variant="ghost"
                      size="sm"
                      navigate={~p"/event/#{ev["id"]}?tab=seeds"}
                    >
                      Seeding
                    </.btn>
                    <.btn
                      variant="ghost"
                      size="sm"
                      navigate={~p"/event/#{ev["id"]}?tab=results"}
                    >
                      Results
                    </.btn>
                  </div>
                </div>
              </div>
            </section>
          <% true -> %>
            <.empty_state
              icon="hero-exclamation-triangle"
              title={
                if(@error == :not_found,
                  do: "No tournament with that slug was found",
                  else: "Couldn't load this tournament right now"
                )
              }
            >
              <:body>
                <%= if @error == :not_found do %>
                  The tournament may have been removed from start.gg.
                <% else %>
                  The start.gg API may be unhappy right now — try again in a moment.
                <% end %>
              </:body>
              <:action>
                <.btn variant="primary" navigate={~p"/"}>Back to browsing</.btn>
              </:action>
            </.empty_state>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp location_label(tournament) do
    city = tournament["city"]
    state = tournament["addrState"]
    country = tournament["countryCode"]

    cond do
      city && state -> "#{city}, #{state}"
      city -> city
      state -> state
      country -> country
      true -> "online"
    end
  end

  defp venue_label(tournament) do
    tournament["venueName"] || tournament["venueAddress"] || "—"
  end

  defp date_range(tournament) do
    timezone = tournament["timezone"] || "UTC"

    case {tournament["startAt"], tournament["endAt"]} do
      {nil, _} ->
        "TBA"

      {start_at, nil} ->
        date(start_at, timezone)

      {start_at, end_at} ->
        start_date = short_date(start_at, timezone)
        end_date = short_date(end_at, timezone)

        if start_date == end_date, do: start_date, else: "#{start_date} – #{end_date}"
    end
  end

  defp format_entrants(tournament) do
    total =
      (tournament["events"] || [])
      |> Enum.reduce(0, fn event, acc -> acc + (event["numEntrants"] || 0) end)

    if total > 0, do: "#{total} total entrants", else: "—"
  end

  defp state_label(state) when state in [2, "ACTIVE"], do: "active"
  defp state_label(state) when state in [3, "COMPLETED"], do: "completed"
  defp state_label(_), do: "upcoming"
end
