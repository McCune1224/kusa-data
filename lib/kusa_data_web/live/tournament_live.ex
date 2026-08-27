defmodule KusaDataWeb.TournamentLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Tournaments

  @default_game "melee"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       tournament: nil,
       error: nil,
       loading: true,
       slug: nil,
       game: @default_game,
       games: [],
       event_count: 0,
       bookmarked: false,
       watched: false,
       nav: :tournaments
     )
     |> stream_configure(:events, dom_id: fn e -> "event-#{e["id"]}" end)
     |> stream(:events, [])}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    slug = slug |> String.trim() |> bare_slug()
    game = selected_game(params["game"])

    socket =
      assign(socket,
        tournament: nil,
        error: nil,
        loading: true,
        slug: slug,
        game: game,
        bookmarked: bookmark_status(socket.assigns.current_user, slug),
        watched: watch_status(socket.assigns.current_user, slug),
        nav: :tournaments
      )

    socket = spawn_load(socket, slug)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_result, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, tournament, _status} ->
        events = decorate_events(tournament["events"] || [])
        games = available_games(events)
        visible = visible_events(events, socket.assigns.game)

        socket =
          socket
          |> assign(
            tournament: Map.put(tournament, "events", events),
            error: nil,
            loading: false,
            load_ref: nil,
            games: games,
            event_count: length(visible)
          )

        {:noreply, stream(socket, :events, visible, reset: true)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(tournament: nil, error: reason, loading: false, load_ref: nil, games: [])
         |> stream(:events, [], reset: true)}
    end
  end

  def handle_info({:load_result, _ref, _result}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("bookmark", _params, socket) do
    user = socket.assigns.current_user

    if user do
      slug = "tournament/#{socket.assigns.slug}"
      snapshot = bookmark_snapshot(socket.assigns.tournament)
      {:ok, _} = KusaData.Bookmarks.bookmark(user, slug, snapshot)

      {:noreply,
       assign(socket, bookmarked: true) |> put_flash(:info, "Saved to your tournaments.")}
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Login is optional — it's only used to save your bookmarks and watches."
       )
       |> push_navigate(
         to:
           "/auth?mode=login&return_to=#{URI.encode_www_form("/tournament/#{socket.assigns.slug}")}"
       )}
    end
  end

  @impl true
  def handle_event("unbookmark", _params, socket) do
    if socket.assigns.current_user do
      KusaData.Bookmarks.unbookmark(
        socket.assigns.current_user,
        "tournament/#{socket.assigns.slug}"
      )

      {:noreply,
       assign(socket, bookmarked: false) |> put_flash(:info, "Removed from your tournaments.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("watch", _params, socket) do
    if socket.assigns.current_user do
      {:ok, _} =
        KusaData.Watches.watch(socket.assigns.current_user, "tournament", socket.assigns.slug)

      {:noreply, assign(socket, watched: true) |> put_flash(:info, "Tournament watch enabled.")}
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Login is optional — it's only used to save your bookmarks and watches."
       )
       |> push_navigate(
         to:
           "/auth?mode=login&return_to=#{URI.encode_www_form("/tournament/#{socket.assigns.slug}")}"
       )}
    end
  end

  @impl true
  def handle_event("unwatch", _params, socket) do
    if socket.assigns.current_user do
      :ok =
        KusaData.Watches.unwatch(socket.assigns.current_user, "tournament", socket.assigns.slug)

      {:noreply, assign(socket, watched: false) |> put_flash(:info, "Tournament watch removed.")}
    else
      {:noreply, socket}
    end
  end

  defp watch_status(nil, _slug), do: false

  defp watch_status(user, slug) do
    if KusaData.Accounts.repo_configured?(),
      do: KusaData.Watches.watched?(user, "tournament", slug),
      else: false
  end

  defp bookmark_status(nil, _slug), do: false

  defp bookmark_status(user, slug) do
    if KusaData.Accounts.repo_configured?() do
      KusaData.Bookmarks.bookmarked?(user, "tournament/#{slug}")
    else
      false
    end
  end

  defp bookmark_snapshot(nil), do: %{}

  defp bookmark_snapshot(tournament) do
    Map.take(tournament, [
      "name",
      "slug",
      "city",
      "addrState",
      "countryCode",
      "startAt",
      "endAt",
      "venueName",
      "timezone"
    ])
  end

  defp spawn_load(socket, slug) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:load_result, ref, Tournaments.by_slug(slug)})
    end)

    assign(socket, load_ref: ref)
  end

  # Normalizes each event's game identity (registering new games from the
  # payload) so templates never re-derive it.
  defp decorate_events(events) do
    Enum.map(events, fn event ->
      slug =
        case Games.normalize(event["videogame"]) do
          %{slug: slug} -> slug
          _ -> nil
        end

      Map.put(event, "game_slug", slug)
    end)
  end

  defp available_games(events) do
    events
    |> Enum.map(& &1["game_slug"])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp visible_events(events, "all"), do: events
  defp visible_events(events, game), do: Enum.filter(events, &(&1["game_slug"] == game))

  defp selected_game("all"), do: "all"

  defp selected_game(slug) when is_binary(slug) do
    case Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> @default_game
    end
  end

  defp selected_game(_), do: @default_game

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="animate-fade-up space-y-6">
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
            <span class="sr-only">Noir Bento</span>
            <section class="rounded-[24px] border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8">
              <.btn
                variant="ghost"
                size="sm"
                icon="hero-arrow-left"
                navigate={~p"/"}
                class="rounded-xl"
              >
                All tournaments
              </.btn>
              <p class="mt-4 text-[11px] font-bold uppercase tracking-[0.18em] text-[#a3e635]">
                Tournament · Noir Bento
              </p>
              <h1 class="mt-2 text-3xl font-black tracking-[-0.03em] text-[#f5f3ff]">
                {@tournament["name"]}
              </h1>

              <div class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-[15px] text-[var(--muted)]">
                <span class="inline-flex items-center gap-1.5">
                  <.icon name="hero-map-pin" class="size-4 text-[var(--muted)]" />
                  {location_label(@tournament)}
                </span>
                <span class="inline-flex items-center gap-1.5">
                  <.icon name="hero-calendar-days" class="size-4 text-[var(--muted)]" />
                  {date_range(@tournament)}
                </span>
                <%= if venue_label(@tournament) != "—" do %>
                  <span class="inline-flex items-center gap-1.5">
                    <.icon name="hero-building-office" class="size-4 text-[var(--muted)]" />
                    {venue_label(@tournament)}
                  </span>
                <% end %>
                <a
                  href={"https://www.start.gg/#{@tournament["slug"]}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1.5 transition-colors hover:text-[#f5f3ff]"
                >
                  <.icon name="hero-arrow-top-right-on-square" class="size-4" /> start.gg
                </a>
              </div>

              <%= if format_entrants(@tournament) != "—" do %>
                <p class="mt-3 font-mono text-[13px] text-[var(--muted)]">
                  {format_entrants(@tournament)}
                </p>
              <% end %>

              <div class="mt-5 flex flex-wrap gap-2">
                <%= if @bookmarked do %>
                  <.btn
                    variant="ghost"
                    size="sm"
                    phx-click="unbookmark"
                    icon="hero-bookmark-slash"
                    class="rounded-xl"
                  >
                    Saved
                  </.btn>
                <% else %>
                  <.btn
                    variant="secondary"
                    size="sm"
                    phx-click="bookmark"
                    icon="hero-bookmark"
                    class="rounded-xl"
                  >
                    Save tournament
                  </.btn>
                <% end %>
                <%= if @watched do %>
                  <.btn
                    variant="ghost"
                    size="sm"
                    phx-click="unwatch"
                    icon="hero-bell-slash"
                    class="rounded-xl"
                  >
                    Watching
                  </.btn>
                <% else %>
                  <.btn
                    variant="ghost"
                    size="sm"
                    phx-click="watch"
                    icon="hero-bell"
                    class="rounded-xl"
                  >
                    Watch changes
                  </.btn>
                <% end %>
                <a
                  href={"/tournament/#{@slug}/calendar.ics"}
                  class="inline-flex items-center gap-2 rounded-xl border border-[var(--border)] bg-[var(--surface2)] px-3 py-2 text-xs font-semibold text-[var(--muted)] transition-colors hover:border-[var(--border2)] hover:text-[#f5f3ff]"
                >
                  <.icon name="hero-calendar-days" class="size-4" /> Add to calendar
                </a>
              </div>
            </section>

            <section class="rounded-2xl border border-[var(--border)] bg-[var(--surface)]/80 p-5 backdrop-blur-sm sm:p-6">
              <div class="flex flex-wrap items-baseline justify-between gap-3">
                <h2 class="text-lg font-semibold tracking-tight text-stone-100">Events</h2>
                <span class="font-mono text-[13px] text-stone-400">
                  {@event_count}
                </span>
              </div>

              <%= if length(@games) > 0 do %>
                <div class="mt-4 flex flex-wrap items-center gap-1">
                  <.link
                    patch={game_path(@slug, "all")}
                    class={game_tab_class(@game == "all")}
                  >
                    All games
                  </.link>
                  <%= for game_slug <- @games do %>
                    <.link
                      patch={game_path(@slug, game_slug)}
                      class={game_tab_class(@game == game_slug)}
                    >
                      {game_label(game_slug)}
                    </.link>
                  <% end %>
                </div>
              <% end %>

              <div
                id="events"
                phx-update="stream"
                class="mt-4 grid gap-3 sm:grid-cols-2"
              >
                <div
                  id="events-empty"
                  class="hidden px-6 py-10 text-center text-[15px] text-stone-400 only:block"
                >
                  No events for this game on this tournament page.
                </div>

                <div
                  :for={{id, ev} <- @streams.events}
                  id={id}
                  class="flex flex-col gap-2 rounded-[20px] border border-[var(--border)] bg-[var(--surface2)] p-5 transition-colors hover:border-[var(--border2)] sm:flex-row sm:items-center sm:justify-between sm:gap-4"
                >
                  <div class="min-w-0">
                    <div class="truncate text-[15px] font-medium text-stone-200">{ev["name"]}</div>
                    <div class="mt-1 text-sm text-stone-400">
                      {ev["numEntrants"] || 0} entrants · {state_label(ev["state"])}
                      <%= if ev["game_slug"] do %>
                        · {game_label(ev["game_slug"])}
                      <% end %>
                    </div>
                  </div>
                  <div class="flex shrink-0 gap-1">
                    <.btn
                      variant="ghost"
                      size="sm"
                      navigate={event_path(ev, "seeds")}
                    >
                      Seeding
                    </.btn>
                    <.btn
                      variant="ghost"
                      size="sm"
                      navigate={event_path(ev, "results")}
                    >
                      Results
                    </.btn>
                  </div>
                </div>
              </div>
              <%!-- Mini Atlas preview — KusaData.Atlas.map_data --%>
              <div class="mt-6 rounded-[20px] border border-[var(--border)] bg-[var(--surface2)] p-5">
                <div class="flex items-center justify-between">
                  <h3 class="text-sm font-bold text-[#f5f3ff]">
                    US Atlas <span class="font-normal text-[var(--muted)]">· mini preview</span>
                  </h3>
                  <.link
                    navigate={~p"/atlas"}
                    class="text-xs font-bold text-[#a3e635] hover:underline"
                  >Open Atlas →</.link>
                </div>
                <div class="mt-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4 text-xs text-[var(--muted)]">
                  Atlas.Graph · <code class="font-mono">KusaData.Atlas.map_data</code>
                  · bubbles by attendees · {location_label(@tournament)} highlighted
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

  defp game_path(slug, "all"), do: "/tournament/#{slug}?game=all"
  defp game_path(slug, game), do: "/tournament/#{slug}?game=#{game}"

  defp event_path(event, tab) do
    game = event["game_slug"]

    if game do
      ~p"/event/#{event["id"]}?tab=#{tab}&game=#{game}"
    else
      ~p"/event/#{event["id"]}?tab=#{tab}"
    end
  end

  defp game_tab_class(active?) do
    base = "rounded-full px-3.5 py-1.5 text-sm font-medium transition-colors"

    if active? do
      "#{base} bg-[#a3e635] text-[#08070b]"
    else
      "#{base} border border-[var(--border)] bg-[var(--surface2)] text-[var(--muted)] hover:border-[var(--border2)] hover:text-[#f5f3ff]"
    end
  end

  defp game_label(slug) do
    case Games.by_slug(slug) do
      %{short_name: name} -> name
      nil -> slug
    end
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
