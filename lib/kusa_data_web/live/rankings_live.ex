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
      <div class="animate-fade-up space-y-6">
        <div class="flex items-center justify-between border-y border-[var(--border)] py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-[var(--muted)]">
          <span><span class="mr-2 inline-block size-2 rounded-full bg-[var(--accent)]"></span>Live bracket index</span>
          <span class="hidden sm:inline">Rankings</span>
          <span class="text-[var(--accent)]">04 — Power</span>
        </div>

        <section class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
              Browse
            </.btn>
            <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-[var(--accent)]">
              Elo power rankings
            </p>
            <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-[var(--text)] sm:text-5xl">
              Who's hot
            </h1>
            <p class="mt-2 max-w-xl text-[15px] leading-relaxed text-[var(--muted)]">
              Deterministic Elo ratings from completed sets, with a configurable tournament floor and a documented time-weight on older results.
            </p>
          </div>
          <div class="hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface)]/60 px-4 py-3 sm:block">
            <p class="font-mono text-xs uppercase tracking-[0.16em] text-[var(--muted)]">
              Elo · time-weighted
            </p>
            <p class="mt-1 text-sm font-semibold text-[var(--text)]">Recent sets weigh more</p>
          </div>
        </section>

        <section class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)]/80 p-4 backdrop-blur sm:p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
              Filters
            </h2>
            <span class="rounded-full border border-[var(--border)] bg-[var(--surface2)] px-3 py-1 font-mono text-[10px] uppercase tracking-[0.16em] text-[var(--muted)]">Noir Bento · pill toggles</span>
          </div>
          <.form
            for={@form}
            id="rankings-filter-form"
            phx-submit="apply"
            class="mt-4 flex flex-wrap items-end gap-3"
          >
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Game</label>
              <.input
                field={@form[:game]}
                type="select"
                options={Enum.map(KusaData.Games.all(), fn g -> {g.short_name, g.slug} end)}
                class="h-10 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)]"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Country</label>
              <.input
                field={@form[:country]}
                type="text"
                placeholder="US"
                class="h-10 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)] placeholder:text-[var(--muted)]"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">State</label>
              <.input
                field={@form[:state]}
                type="text"
                placeholder="IL"
                class="h-10 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)] placeholder:text-[var(--muted)]"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Month</label>
              <.input
                field={@form[:month]}
                type="month"
                class="h-10 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)]"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Min tournaments</label>
              <.input
                field={@form[:min_tournaments]}
                type="number"
                min="1"
                class="h-10 w-24 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)]"
              />
            </div>
            <.btn variant="primary" type="submit" class="rounded-full">Rank</.btn>
          </.form>
          <div class="mt-4 flex flex-wrap gap-2">
            <%= for g <- KusaData.Games.all() do %>
              <span class={[
                "rounded-full border px-3 py-1 text-xs font-medium",
                if(@form[:game].value == g.slug,
                  do: "border-[var(--accent)] bg-[var(--accent)] text-[#08070b]",
                  else: "border-[var(--border)] bg-[var(--surface2)] text-[var(--muted)]"
                )
              ]}>{g.short_name}</span>
            <% end %>
          </div>
        </section>

        <section>
          <%= if @loading do %>
            <div class="grid gap-3">
              <.skeleton :for={_ <- 1..8} class="h-[72px] w-full rounded-[16px]" />
            </div>
          <% else %>
            <%= cond do %>
              <% @error != nil -> %>
                <.empty_state icon="hero-exclamation-triangle" title="Couldn't load rankings">
                  <:body>
                    Something went wrong talking to start.gg. Please try again in a moment.
                  </:body>
                </.empty_state>
              <% @data == nil || @data["rankings"] == [] -> %>
                <.empty_state icon="hero-trophy" title="No eligible players">
                  <:body>No players met the tournament floor in this scope yet.</:body>
                </.empty_state>
              <% true -> %>
                <div id="ranking-rows" class="grid gap-3">
                  <div
                    :for={{player, rank} <- Enum.with_index(@data["rankings"], 1)}
                    class="group flex items-center gap-4 rounded-[16px] border border-[var(--border)] bg-[var(--surface)]/80 p-4 backdrop-blur transition-colors hover:border-[var(--border2)] hover:bg-[var(--surface2)]/80"
                  >
                    <div class={[
                      "flex size-10 shrink-0 items-center justify-center rounded-full border font-mono text-sm font-bold",
                      rank_badge_class(rank)
                    ]}>
                      {rank}
                    </div>
                    <.avatar name={player["gamer_tag"] || "?"} class="size-10 text-sm" />
                    <div class="min-w-0 flex-1">
                      <.link
                        navigate={~p"/player/#{player["player_id"]}"}
                        class="truncate text-[15px] font-semibold text-[var(--text)] transition-colors group-hover:text-[var(--accent)]"
                      >
                        {player["gamer_tag"]}
                      </.link>
                      <div class="flex items-center gap-2 font-mono text-xs text-[var(--muted)]">
                        <span class="text-emerald-400">{player["wins"]}W</span>
                        <span class="text-[var(--muted)]">·</span>
                        <span class="text-rose-400">{player["losses"]}L</span>
                        <span class="hidden sm:inline text-[var(--muted)]">· {player["tournaments"]} events</span>
                      </div>
                    </div>
                    <div class="hidden flex-col items-end sm:flex">
                      <span class="font-mono text-lg font-bold tracking-tight text-[var(--text)]">{player[
                        "rating"
                      ]}</span>
                      <span class="text-[10px] uppercase tracking-[0.14em] text-[var(--muted)]">Elo</span>
                    </div>
                    <div class="hidden w-[64px] shrink-0 sm:block" aria-hidden="true">
                      <svg viewBox="0 0 48 20" class="h-5 w-full">
                        <polyline
                          fill="none"
                          stroke="var(--accent)"
                          stroke-width="1.6"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          points={sparkline_points(rank, player["rating"])}
                        />
                        <polyline
                          fill="none"
                          stroke="rgba(255,255,255,0.12)"
                          stroke-width="1"
                          points="0,10 48,10"
                        />
                      </svg>
                      <div class="mt-1 flex gap-0.5">
                        <span
                          :for={h <- sparkline_bars(rank)}
                          class="flex-1 rounded-full bg-[var(--accent)]/70"
                          style={"height: #{h}px"}
                        ></span>
                      </div>
                    </div>
                    <span class="sm:hidden font-mono text-sm font-semibold text-[var(--text)]">{player[
                      "rating"
                    ]}</span>
                  </div>
                </div>
                <p class="mt-3 text-xs text-[var(--muted)]">
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

  defp rank_badge_class(1), do: "border-amber-400/40 bg-amber-400/15 text-amber-300"
  defp rank_badge_class(2), do: "border-zinc-400/30 bg-zinc-400/10 text-zinc-200"
  defp rank_badge_class(3), do: "border-amber-600/30 bg-amber-600/10 text-amber-400"
  defp rank_badge_class(_), do: "border-[var(--border)] bg-[var(--surface2)] text-[var(--muted)]"

  defp sparkline_points(rank, rating) do
    seed = rem((rating || 1500) + rank * 37, 100)
    y = fn v -> 10 - v / 12 end
    a = rem(seed, 7) - 3
    b = rem(seed * 2, 7) - 3
    c = rem(seed * 3, 7) - 3
    "0,#{y.(a)} 12,#{y.(b)} 24,#{y.(c)} 36,#{y.(a + b)} 48,#{y.(b)}"
  end

  defp sparkline_bars(rank) do
    base = [4, 8, 6, 10, 7]
    Enum.map(base, fn h -> max(3, rem(h + rank * 2, 11) + 3) end)
  end

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
