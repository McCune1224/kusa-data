defmodule KusaDataWeb.EventLive do
  use KusaDataWeb, :live_view

  alias KusaData.Events

  @impl true
  def mount(_params, _session, socket) do
    filter_form = to_form(%{"filter" => ""})

    {:ok,
     assign(socket,
       event: nil,
       tab: "seeds",
       error: nil,
       loading: true,
       filter_form: filter_form,
       rows_all: [],
       total: 0,
       identifier: nil,
       game_slug: nil,
       recap: nil,
       watched: false,
       nav: :tournaments
     )
     |> stream_configure(:rows, dom_id: fn row -> "row-#{row["id"] || row["entrant_id"]}" end)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    identifier = params["event"]
    tab = if params["tab"] in ["seeds", "results", "standings"], do: params["tab"], else: "seeds"

    socket =
      socket
      |> assign(
        tab: tab,
        event: nil,
        error: nil,
        loading: true,
        game_slug: game_slug_from_params(params["game"]),
        watched: watch_status(socket.assigns.current_user, identifier)
      )
      |> spawn_event_load()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:event_loaded, ref, result}, %{assigns: %{event_ref: ref}} = socket) do
    case result do
      {:ok, event, _status} ->
        tab = socket.assigns.tab

        socket =
          socket
          |> assign(
            event: event,
            error: nil,
            event_ref: nil,
            game_slug: game_slug_from_event(event)
          )

        {:noreply, spawn_tab_load(socket, event, tab)}

      {:error, reason} ->
        {:noreply, assign(socket, event: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:event_loaded, _ref, _result}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tab_loaded, ref, result}, %{assigns: %{tab_ref: ref}} = socket) do
    socket = assign(socket, tab_ref: nil)

    case result do
      {:ok, %{"analysis" => %{} = analysis}, _status} ->
        rows = analysis["entrants"]
        recap = KusaData.Stats.BracketEngine.recap(analysis)
        anomalies = analysis["anomalies"]

        socket =
          socket
          |> assign(
            loading: false,
            total: length(rows),
            rows_all: rows,
            recap: recap,
            anomalies: anomalies
          )
          |> stream(:rows, rows, reset: true)

        {:noreply, socket}

      {:ok, rows, _status} when is_list(rows) ->
        socket =
          socket
          |> assign(
            loading: false,
            total: length(rows),
            rows_all: rows,
            recap: nil,
            anomalies: []
          )
          |> stream(:rows, rows, reset: true)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(loading: false, error: reason, rows_all: [], recap: nil, anomalies: [])
         |> stream(:rows, [], reset: true)}
    end
  end

  def handle_info({:tab_loaded, _ref, _result}, socket) do
    {:noreply, socket}
  end

  defp spawn_event_load(socket) do
    identifier = socket.assigns.identifier
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:event_loaded, ref, Events.get(identifier)})
    end)

    assign(socket, event_ref: ref)
  end

  defp spawn_tab_load(socket, event, tab) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      result =
        case tab do
          "seeds" -> Events.seeding(event["id"])
          "results" -> Events.results(event["id"])
          "standings" -> Events.analytics(event["id"])
        end

      send(parent, {:tab_loaded, ref, result})
    end)

    assign(socket, tab_ref: ref, loading: true)
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    event = socket.assigns.event
    Events.clear_cache(event["id"])
    socket = socket |> assign(loading: true, tab: socket.assigns.tab)
    {:noreply, spawn_event_load(socket)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter = filter || ""
    rows = filter_rows(socket.assigns.rows_all, filter)

    {:noreply,
     socket
     |> assign(filter_form: to_form(%{"filter" => filter}))
     |> stream(:rows, rows, reset: true)}
  end

  @impl true
  def handle_event("tab-seeds", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/event/#{socket.assigns.event["id"]}?tab=seeds")}
  end

  @impl true
  def handle_event("tab-results", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/event/#{socket.assigns.event["id"]}?tab=results")}
  end

  @impl true
  def handle_event("tab-standings", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/event/#{socket.assigns.event["id"]}?tab=standings")}
  end

  @impl true
  def handle_event("watch", _params, socket) do
    if socket.assigns.current_user do
      {:ok, _} =
        KusaData.Watches.watch(socket.assigns.current_user, "event", socket.assigns.identifier)

      {:noreply, assign(socket, watched: true) |> put_flash(:info, "Event watch enabled.")}
    else
      {:noreply,
       push_navigate(
         socket,
         to:
           "/auth?mode=login&return_to=#{URI.encode_www_form("/event/#{socket.assigns.identifier}")}"
       )}
    end
  end

  @impl true
  def handle_event("unwatch", _params, socket) do
    if socket.assigns.current_user do
      :ok =
        KusaData.Watches.unwatch(socket.assigns.current_user, "event", socket.assigns.identifier)

      {:noreply, assign(socket, watched: false) |> put_flash(:info, "Event watch removed.")}
    else
      {:noreply, socket}
    end
  end

  defp watch_status(nil, _id), do: false

  defp watch_status(user, id) do
    if KusaData.Accounts.repo_configured?(),
      do: KusaData.Watches.watched?(user, "event", id),
      else: false
  end

  defp filter_rows(rows, ""), do: rows

  defp filter_rows(rows, filter) do
    needle = String.downcase(filter)

    Enum.filter(rows, fn row ->
      String.contains?(String.downcase(row["name"]), needle)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <%= if @event do %>
          <div class="flex flex-wrap items-center justify-between gap-3">
            <.btn
              variant="ghost"
              size="sm"
              icon="hero-arrow-left"
              navigate={tournament_back_path(@event["tournament"]["slug"], @game_slug)}
            >
              {@event["tournament"]["name"]}
            </.btn>

            <div class="flex shrink-0 items-center gap-1">
              <%= if @watched do %>
                <.btn variant="ghost" size="sm" icon="hero-bell-slash" phx-click="unwatch">
                  Watching
                </.btn>
              <% else %>
                <.btn variant="ghost" size="sm" icon="hero-bell" phx-click="watch">
                  Watch
                </.btn>
              <% end %>
              <.btn
                variant="ghost"
                size="sm"
                icon="hero-arrow-path"
                phx-click="refresh"
                phx-disable-with="Refreshing…"
              >
                Refresh
              </.btn>
              <.btn
                variant="ghost"
                size="sm"
                icon="hero-arrow-top-right-on-square"
                href={"https://www.start.gg/#{@event["slug"]}"}
                target="_blank"
                rel="noopener noreferrer"
              >
                start.gg
              </.btn>
            </div>
          </div>

          <div class="mt-5">
            <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">Event</p>
            <div class="mt-2 flex flex-wrap items-center gap-3">
              <h1 class="text-2xl font-semibold tracking-tight text-stone-50">
                {@event["name"]}
              </h1>
              <%= if @game_slug do %>
                <.badge tone="accent">{game_label(@game_slug)}</.badge>
              <% end %>
            </div>
            <div class="mt-2 flex flex-wrap items-center gap-2 text-[15px] text-stone-400">
              <span>{@event["numEntrants"] || 0} entrants</span>
              <.badge tone={state_tone(@event["state"])} dot>
                {state_label(@event["state"])}
              </.badge>
            </div>
          </div>

          <div class="mt-8 grid grid-cols-3 gap-1 rounded-xl border border-stone-800 bg-stone-900/60 p-1 sm:inline-grid">
            <button
              type="button"
              id="tab-seeds"
              phx-click="tab-seeds"
              class={tab_class(@tab == "seeds")}
            >
              <.icon name="hero-list-bullet" class="size-4" />
              <span>Seeding</span>
              <span class="font-mono">· {@total}</span>
            </button>
            <button
              type="button"
              id="tab-results"
              phx-click="tab-results"
              class={tab_class(@tab == "results")}
            >
              <.icon name="hero-trophy" class="size-4" />
              <span>Results</span>
              <span class="font-mono">· {@total}</span>
            </button>
            <button
              type="button"
              id="tab-standings"
              phx-click="tab-standings"
              class={tab_class(@tab == "standings")}
            >
              <.icon name="hero-chart-bar" class="size-4" />
              <span>Standings</span>
              <span class="font-mono">· {@total}</span>
            </button>
          </div>

          <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
            <.form
              for={@filter_form}
              id="rows-filter-form"
              phx-change="filter"
              class="relative w-full max-w-xs"
            >
              <span class="pointer-events-none absolute inset-y-0 left-0 z-10 flex items-center pl-3.5">
                <.icon name="hero-magnifying-glass" class="size-4 text-stone-600" />
              </span>
              <.input
                field={@filter_form[:filter]}
                type="text"
                placeholder={filter_placeholder(@tab)}
                class="h-10 w-full rounded-xl border border-stone-800 bg-stone-950 pl-10 pr-4 text-sm text-stone-200 placeholder-stone-600 outline-none transition focus:border-lime-400/50 focus:ring-2 focus:ring-lime-400/15"
              />
            </.form>
            <span class="shrink-0 font-mono text-[13px] text-stone-400">{@total} shown</span>
          </div>

          <div class="mt-4 overflow-hidden rounded-xl border border-stone-800/80">
            <div class="flex items-center gap-4 border-b border-stone-800 bg-stone-900/60 px-5 py-3 text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              <div class="w-16 shrink-0"></div>
              <div class="flex-1">Entrant</div>
              <div :if={@tab == "standings"} class="hidden w-28 shrink-0 justify-end sm:flex">
                Sets
              </div>
              <div :if={@tab == "standings"} class="hidden w-16 shrink-0 justify-end sm:flex">
                Δ
              </div>
              <div class="hidden w-24 shrink-0 justify-end sm:flex"></div>
            </div>

            <%= if @loading do %>
              <div>
                <.skeleton
                  :for={_ <- 1..5}
                  class="h-12 w-full rounded-none border-b border-stone-800/60 last:border-b-0"
                />
              </div>
            <% else %>
              <div id="rows" phx-update="stream">
                <div
                  id="rows-empty"
                  class="hidden px-6 py-10 text-center text-[15px] text-stone-400 only:block"
                >
                  No matching entries.
                </div>

                <div
                  :for={{id, row} <- @streams.rows}
                  id={id}
                  class={row_class(@tab, row)}
                >
                  <div class="w-16 shrink-0 font-mono text-sm">
                    <%= cond do %>
                      <% @tab == "seeds" -> %>
                        <%= if tone = seed_badge_tone(row["seed"]) do %>
                          <.badge tone={tone} class="font-mono">
                            {seed_badge(row["seed"])}
                          </.badge>
                        <% else %>
                          <span class="text-stone-500">{seed_badge(row["seed"])}</span>
                        <% end %>
                      <% @tab == "standings" -> %>
                        <span class={["font-bold", placement_class(row["placement"])]}>
                          #{row["placement"]}
                        </span>
                      <% true -> %>
                        <span class={["font-bold", placement_class(row["placement"])]}>
                          #{row["placement"]}
                        </span>
                    <% end %>
                  </div>
                  <div class="min-w-0 flex-1 truncate text-[15px] font-medium text-stone-200">
                    <%= if row["player_id"] do %>
                      <.link
                        navigate={player_link(@game_slug, row["player_id"])}
                        class="truncate transition-colors hover:text-lime-300"
                      >
                        {row["name"]}
                      </.link>
                    <% else %>
                      {row["name"]}
                    <% end %>
                    <%= if @tab == "standings" && row["reason"] do %>
                      <.badge tone={reason_tone(row["reason"])} class="ml-2">
                        {reason_label(row["reason"])}
                      </.badge>
                    <% end %>
                  </div>
                  <div :if={@tab == "standings"} class="hidden w-28 shrink-0 justify-end sm:flex">
                    <span class="font-mono text-[13px]">
                      <span class={
                        if(row["wins"] >= row["losses"],
                          do: "text-emerald-400",
                          else: "text-stone-400"
                        )
                      }>
                        {row["wins"]}W
                      </span>
                      <span class="mx-1 text-stone-600">-</span>
                      <span class={
                        if(row["losses"] > row["wins"], do: "text-rose-400", else: "text-stone-400")
                      }>
                        {row["losses"]}L
                      </span>
                      <span class="ml-1.5 text-stone-600">({row["games_won"]}-{row["games_lost"]})</span>
                    </span>
                  </div>
                  <div :if={@tab == "standings"} class="hidden w-16 shrink-0 justify-end sm:flex">
                    <%= if is_integer(row["seed_delta"]) do %>
                      <span class={delta_class(row["seed_delta"])}>
                        {if row["seed_delta"] > 0, do: "+", else: ""}{row["seed_delta"]}
                      </span>
                    <% else %>
                      <span class="text-stone-600">—</span>
                    <% end %>
                  </div>
                  <div class="hidden w-24 shrink-0 justify-end sm:flex">
                    <%= if @tab == "results" && top8?(row["placement"]) do %>
                      <.badge tone={top8_tone(row["placement"])}>Top 8</.badge>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @tab == "standings" && @recap do %>
            <div class="mt-6 grid gap-4 md:grid-cols-3">
              <.card class="p-5 md:col-span-2">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Tournament recap
                  </h2>
                </div>
                <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                  <.stat label="Entrants" value={@recap["entrant_count"]} />
                  <.stat label="Matches" value={@recap["match_count"]} />
                  <.stat
                    label="Avg sets / entrant"
                    value={
                      if(is_number(@recap["avg_sets_per_entrant"]),
                        do: @recap["avg_sets_per_entrant"],
                        else: "—"
                      )
                    }
                  />
                  <.stat
                    label="DQ rate"
                    value={
                      if(is_number(@recap["dq_rate"]),
                        do: "#{@recap["dq_rate"]}%",
                        else: "unavailable"
                      )
                    }
                  />
                </div>
              </.card>

              <.card class="p-5">
                <div class="flex items-center gap-2">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Bracket anomalies
                  </h2>
                  <span class="font-mono text-[13px] text-stone-500">{length(@anomalies)}</span>
                </div>
                <div id="anomalies" class="mt-4 space-y-2">
                  <div class="hidden only:block text-sm text-stone-500">
                    No changed seeds, reseeds, or unseeded top finishes.
                  </div>
                  <div
                    :for={anomaly <- @anomalies}
                    class="flex items-center justify-between gap-3 rounded-md px-3 py-2.5 transition-colors hover:bg-stone-900/60"
                  >
                    <span class="min-w-0 truncate text-[15px] font-medium text-stone-200">
                      {anomaly["name"]}
                    </span>
                    <.badge tone={reason_tone(anomaly["reason"])}>
                      {reason_label(anomaly["reason"])}
                    </.badge>
                  </div>
                </div>
              </.card>
            </div>
          <% end %>
        <% else %>
          <%= if @loading do %>
            <div class="mt-6 space-y-3">
              <.skeleton class="h-8 w-48" />
              <.skeleton class="h-4 w-72" />
              <.skeleton class="mt-8 h-10 w-40" />
              <div class="mt-6 rounded-xl border border-stone-800/80">
                <.skeleton
                  :for={_ <- 1..6}
                  class="h-14 w-full rounded-none border-b border-stone-800/60 last:border-b-0"
                />
              </div>
            </div>
          <% else %>
            <.empty_state
              icon="hero-exclamation-triangle"
              title={
                if(@error == :not_found,
                  do: "No event with that id or slug was found",
                  else: "Couldn't load this event right now"
                )
              }
            >
              <:body>
                <%= if @error == :not_found do %>
                  The event may have been removed from start.gg.
                <% else %>
                  The start.gg API may be unhappy right now — try again in a moment.
                <% end %>
              </:body>
              <:action>
                <.btn variant="primary" navigate={~p"/"}>Back to browsing</.btn>
              </:action>
            </.empty_state>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp tab_class(active?) do
    base =
      "flex items-center justify-center gap-1.5 rounded-md px-4 py-1.5 text-sm font-medium transition-colors"

    if active? do
      "#{base} bg-lime-400 text-stone-950"
    else
      "#{base} text-stone-400 hover:bg-stone-800/60 hover:text-stone-100"
    end
  end

  defp row_class("seeds", _row),
    do:
      "flex items-center gap-4 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3 transition-colors last:border-b-0 hover:bg-stone-900/70"

  defp row_class("results", row),
    do:
      "flex items-center gap-4 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3 transition-colors last:border-b-0 hover:bg-stone-900/70 " <>
        top8_highlight(row["placement"])

  defp row_class("standings", row),
    do:
      "flex items-center gap-4 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3 transition-colors last:border-b-0 hover:bg-stone-900/70 " <>
        top8_highlight(row["placement"])

  defp row_class(_tab, _row),
    do:
      "flex items-center gap-4 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3 transition-colors last:border-b-0 hover:bg-stone-900/70"

  defp top8_highlight(placement) when placement in [1, 2, 3], do: "bg-amber-400/5"
  defp top8_highlight(placement) when placement in 4..8, do: "bg-lime-400/5"
  defp top8_highlight(_), do: ""

  defp placement_class(1), do: "text-amber-400"
  defp placement_class(2), do: "text-stone-300"
  defp placement_class(3), do: "text-amber-600"
  defp placement_class(_), do: "text-stone-500"

  defp seed_badge(nil), do: "—"
  defp seed_badge(seed), do: "##{seed}"

  defp seed_badge_tone(1), do: "emerald"
  defp seed_badge_tone(seed) when seed in [2, 3, 4], do: "amber"
  defp seed_badge_tone(_), do: nil

  defp top8?(placement) when is_integer(placement), do: placement in 1..8
  defp top8?(_), do: false

  defp top8_tone(placement) when placement in [1, 2, 3], do: "amber"
  defp top8_tone(placement) when placement in 4..8, do: "accent"

  defp filter_placeholder("seeds"), do: "Filter by tag…"
  defp filter_placeholder("results"), do: "Filter by tag…"
  defp filter_placeholder("standings"), do: "Filter by tag…"

  defp reason_tone("reseeded"), do: "emerald"
  defp reason_tone("unseeded_top_finish"), do: "amber"
  defp reason_tone("changed_seed"), do: "rose"
  defp reason_tone(_), do: "neutral"

  defp reason_label("reseeded"), do: "reseeded"
  defp reason_label("unseeded_top_finish"), do: "unseeded top finish"
  defp reason_label("changed_seed"), do: "changed seed"
  defp reason_label(reason), do: reason

  defp delta_class(delta) when delta >= 2, do: "font-bold text-emerald-400"
  defp delta_class(delta) when delta <= -2, do: "font-bold text-rose-400"
  defp delta_class(_), do: "text-stone-500"

  # The event's own game identity is canonical; the URL param is only a
  # fallback for links that were built before the event data arrived.
  defp game_slug_from_event(event) do
    case KusaData.Games.normalize(event["videogame"]) do
      %{slug: slug} -> slug
      _ -> nil
    end
  end

  defp game_slug_from_params(nil), do: nil

  defp game_slug_from_params(slug) when is_binary(slug) do
    case KusaData.Games.by_slug(slug) do
      %{slug: _} -> slug
      nil -> nil
    end
  end

  defp game_slug_from_params(_), do: nil

  defp player_link(nil, player_id), do: ~p"/player/#{player_id}"
  defp player_link(game, player_id), do: ~p"/game/#{game}/player/#{player_id}"

  defp tournament_back_path(slug, nil), do: ~p"/tournament/#{bare_slug(slug)}"
  defp tournament_back_path(slug, game), do: ~p"/tournament/#{bare_slug(slug)}?game=#{game}"

  defp game_label(slug) do
    case KusaData.Games.by_slug(slug) do
      %{short_name: name} -> name
      nil -> slug
    end
  end

  defp state_tone(state) when state in ["COMPLETED", 3], do: "emerald"
  defp state_tone(state) when state in ["ACTIVE", 2], do: "amber"
  defp state_tone(_), do: "accent"

  defp state_label(state) when state in ["COMPLETED", 3], do: "completed"
  defp state_label(state) when state in ["ACTIVE", 2], do: "in progress"
  defp state_label(_), do: "upcoming"
end
