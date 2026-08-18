defmodule KusaDataWeb.RankingsLive do
  use KusaDataWeb, :live_view

  alias KusaData.Rankings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :tournaments,
       data: nil,
       error: nil,
       loading: true,
       form:
         to_form(%{
           "game" => "melee",
           "country" => "",
           "state" => "",
           "month" => "",
           "min_tournaments" => "3"
         })
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    game = params["game"] || "melee"
    country = blank(params["country"])
    state = blank(params["state"])
    month = params["month"]
    min_tournaments = params["min_tournaments"] || "3"

    {from, to} = month_bounds(month)

    socket =
      socket
      |> assign(
        data: nil,
        error: nil,
        loading: true,
        form:
          to_form(%{
            "game" => game,
            "country" => country || "",
            "state" => state || "",
            "month" => month || "",
            "min_tournaments" => min_tournaments
          })
      )
      |> spawn_load(%{
        game: game,
        country: country,
        state: state,
        from: from,
        to: to,
        min_tournaments: parse_int(min_tournaments, 3)
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:rankings_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        {:noreply, assign(socket, data: data, error: nil, loading: false, load_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:rankings_loaded, _ref, _result}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("apply", params, socket) do
    query =
      ["game", "country", "state", "month", "min_tournaments"]
      |> Enum.reject(fn key -> blank(params[key]) in [nil, ""] end)
      |> Enum.map(fn key -> "#{key}=#{URI.encode_www_form(params[key])}" end)
      |> Enum.join("&")

    {:noreply, push_patch(socket, to: "/rankings?#{query}")}
  end

  defp spawn_load(socket, opts) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:rankings_loaded, ref, Rankings.rank(opts)})
    end)

    assign(socket, load_ref: ref)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="desk-grid animate-fade-up">
        <div class="mb-5 flex items-center justify-between border-y border-stone-800 py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-stone-500">
          <span><span class="mr-2 inline-block size-2 bg-lime-400"></span>Live bracket index</span>
          <span class="hidden sm:inline">Rankings</span>
          <span class="text-orange-300">04 — Power</span>
        </div>

        <section>
          <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
            Browse
          </.btn>
          <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-lime-300">
            Elo power rankings
          </p>
          <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-stone-50 sm:text-5xl">
            Who's hot
          </h1>
          <p class="mt-2 max-w-xl text-[15px] leading-relaxed text-stone-400">
            Deterministic Elo ratings from completed sets, with a configurable
            tournament floor and a documented time-weight on older results.
          </p>
        </section>

        <.form
          for={@form}
          id="rankings-filter-form"
          phx-submit="apply"
          class="mt-8 flex flex-wrap items-end gap-3 rounded-xl border border-stone-800 bg-stone-900/40 p-4"
        >
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Game</label>
            <.input
              field={@form[:game]}
              type="select"
              options={Enum.map(KusaData.Games.all(), fn g -> {g.short_name, g.slug} end)}
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Country</label>
            <.input
              field={@form[:country]}
              type="text"
              placeholder="US"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">State</label>
            <.input
              field={@form[:state]}
              type="text"
              placeholder="IL"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Month</label>
            <.input
              field={@form[:month]}
              type="month"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Min tournaments</label>
            <.input
              field={@form[:min_tournaments]}
              type="number"
              min="1"
              class="h-10 w-24 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <.btn variant="primary" type="submit" class="rounded-none">Rank</.btn>
        </.form>

        <section class="mt-8">
          <%= if @loading do %>
            <div class="space-y-2">
              <.skeleton :for={_ <- 1..10} class="h-12 w-full rounded-none" />
            </div>
          <% else %>
            <%= if @data == nil || @data["rankings"] == [] do %>
              <.empty_state icon="hero-trophy" title="No eligible players">
                <:body>
                  No players met the tournament floor in this scope yet. {if @error,
                    do: " (#{inspect(@error)})"}
                </:body>
              </.empty_state>
            <% else %>
              <div class="overflow-hidden rounded-xl border border-stone-800/80">
                <div class="flex items-center gap-4 border-b border-stone-800 bg-stone-900/60 px-5 py-3 text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                  <div class="w-12 shrink-0">#</div>
                  <div class="flex-1">Player</div>
                  <div class="hidden w-16 shrink-0 justify-end sm:flex">Rating</div>
                  <div class="hidden w-20 shrink-0 justify-end sm:flex">W-L</div>
                  <div class="hidden w-16 shrink-0 justify-end sm:flex">Events</div>
                </div>

                <div id="ranking-rows">
                  <div
                    :for={{player, rank} <- Enum.with_index(@data["rankings"], 1)}
                    class="flex items-center gap-4 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3 transition-colors last:border-b-0 hover:bg-stone-900/70"
                  >
                    <div class={["w-12 shrink-0 font-mono text-sm font-bold", rank_class(rank)]}>
                      {rank}
                    </div>
                    <div class="min-w-0 flex-1 truncate">
                      <.link
                        navigate={~p"/player/#{player["player_id"]}"}
                        class="truncate text-[15px] font-medium text-stone-200 transition-colors hover:text-lime-300"
                      >
                        {player["gamer_tag"]}
                      </.link>
                    </div>
                    <div class="hidden w-16 shrink-0 justify-end font-mono text-[15px] font-semibold text-stone-100 sm:flex">
                      {player["rating"]}
                    </div>
                    <div class="hidden w-20 shrink-0 justify-end font-mono text-[13px] sm:flex">
                      <span class="text-emerald-400">{player["wins"]}W</span>
                      <span class="mx-1 text-stone-600">-</span>
                      <span class="text-rose-400">{player["losses"]}L</span>
                    </div>
                    <div class="hidden w-16 shrink-0 justify-end font-mono text-[13px] text-stone-400 sm:flex">
                      {player["tournaments"]}
                    </div>
                  </div>
                </div>
              </div>

              <p class="mt-3 text-xs text-stone-500">
                {length(@data["rankings"])} ranked · {@data["players_scanned"]} players scanned · {@data[
                  "tournaments"
                ]} tournaments
              </p>
            <% end %>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp rank_class(1), do: "text-amber-400"
  defp rank_class(2), do: "text-stone-300"
  defp rank_class(3), do: "text-amber-600"
  defp rank_class(_), do: "text-stone-500"

  defp month_bounds(nil), do: {nil, nil}
  defp month_bounds(""), do: {nil, nil}

  defp month_bounds(month) do
    case Date.from_iso8601(month <> "-01") do
      {:ok, first} ->
        last = Date.end_of_month(first)
        from = DateTime.new!(first, ~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()
        to = DateTime.new!(last, ~T[23:59:59], "Etc/UTC") |> DateTime.to_unix()
        {from, to}

      _ ->
        {nil, nil}
    end
  end

  defp parse_int(value, default) do
    case Integer.parse(value) do
      {n, ""} -> max(n, 1)
      _ -> default
    end
  end

  defp blank(nil), do: nil

  defp blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      v -> v
    end
  end

  defp blank(value), do: value
end
