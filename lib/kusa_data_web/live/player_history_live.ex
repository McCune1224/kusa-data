defmodule KusaDataWeb.PlayerHistoryLive do
  use KusaDataWeb, :live_view

  alias KusaData.Games
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :tournaments,
       player_id: nil,
       data: nil,
       graph: nil,
       error: nil,
       loading: true,
       form: to_form(%{"event" => "", "opponent" => "", "from" => "", "to" => "", "game" => ""})
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_id = params["id"]
    game = valid_game(params["game"])
    event = blank(params["event"])
    opponent = blank(params["opponent"])
    from = iso_to_unix(params["from"])
    to = iso_to_unix(params["to"])

    socket =
      socket
      |> assign(
        player_id: player_id,
        data: nil,
        graph: nil,
        error: nil,
        loading: true,
        form:
          to_form(%{
            "event" => event || "",
            "opponent" => opponent || "",
            "from" => params["from"] || "",
            "to" => params["to"] || "",
            "game" => game || ""
          })
      )
      |> spawn_load(player_id, %{event: event, opponent: opponent, from: from, to: to, game: game})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:history_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data, _status} ->
        graph = build_history_graph(data, socket.assigns.player_id)

        socket =
          assign(socket, data: data, graph: graph, error: nil, loading: false, load_ref: nil)

        {:noreply, push_event(socket, "atlas:data", %{type: "network", graph: graph})}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, graph: nil, error: reason, loading: false)}
    end
  end

  def handle_info({:history_loaded, _ref, _result}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("apply-filters", params, socket) do
    query = %{
      "event" => blank(params["event"]),
      "opponent" => blank(params["opponent"]),
      "from" => params["from"] || "",
      "to" => params["to"] || "",
      "game" => blank(params["game"])
    }

    path =
      Enum.reject(query, fn {_k, v} -> v in [nil, ""] end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    {:noreply, push_patch(socket, to: "/player/#{socket.assigns.player_id}/history?" <> path)}
  end

  defp spawn_load(socket, player_id, filters) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:history_loaded, ref, Players.history(player_id, filters)})
    end)

    assign(socket, load_ref: ref)
  end

  defp build_history_graph(data, player_id) do
    pid_int =
      case Integer.parse(to_string(player_id)) do
        {n, ""} -> n
        _ -> player_id
      end

    gamer_tag = (data && data["gamer_tag"]) || "Player #{player_id}"
    sets = (data && data["sets"]) || []

    opponents =
      sets
      |> Enum.take(12)
      |> Enum.reduce(%{}, fn set, acc ->
        opp = opponent_name(set, player_id)
        opp_id = opponent_id(set, player_id)
        key = opp_id || opp

        Map.update(acc, key, %{name: opp, id: opp_id, count: 1}, fn v ->
          %{v | count: v.count + 1}
        end)
      end)
      |> Map.values()

    focal = %{
      "player_id" => pid_int,
      "gamer_tag" => gamer_tag,
      "is_focal" => true,
      "weight" => max(length(sets), 1)
    }

    {nodes, edges} =
      Enum.reduce(opponents, {[focal], []}, fn opp, {ns, es} ->
        case opp.id do
          nil ->
            {ns, es}

          id ->
            int_id =
              case Integer.parse(to_string(id)) do
                {n, ""} -> n
                _ -> id
              end

            node = %{
              "player_id" => int_id,
              "gamer_tag" => opp.name,
              "is_focal" => false,
              "weight" => opp.count
            }

            edge = %{"source" => pid_int, "target" => int_id, "weight" => opp.count}
            {[node | ns], [edge | es]}
        end
      end)

    nodes =
      if nodes == [focal],
        do: [
          focal,
          %{
            "player_id" => pid_int + 999_999,
            "gamer_tag" => "No opponents",
            "is_focal" => false,
            "weight" => 1
          }
        ],
        else: nodes

    %{"nodes" => Enum.reverse(nodes), "edges" => Enum.reverse(edges)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="space-y-4 animate-fade-up">
        <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/player/#{@player_id}"}>
          Player page
        </.btn>

        <.card class="p-6">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
            Full match history
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[var(--text)]">
            {if @data, do: @data["gamer_tag"], else: "Player #{@player_id}"}
          </h1>
          <%= if @data do %>
            <p class="mt-1 text-[15px] text-[var(--muted)]">
              {format_count(@data["total"])} · {@data["fetched"]} fetched
              <%= if @data["continuation"] do %>
                · truncated at page {@data["continuation"] - 1}
              <% end %>
            </p>
          <% end %>
          <%= if @data && @data["sets"] != [] do %>
            <div class="mt-4">
              <p class="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">
                Form sparkline (last 30)
              </p>
              <svg
                viewBox="0 0 300 40"
                class="mt-2 h-10 w-full"
                role="img"
                aria-label="History sparkline"
              >
                <polyline
                  fill="none"
                  stroke="var(--accent)"
                  stroke-width="2"
                  stroke-linejoin="round"
                  stroke-linecap="round"
                  points={sparkline_points(@data["sets"], @player_id)}
                />
                <polyline
                  fill="none"
                  stroke="rgba(154,149,176,0.25)"
                  stroke-width="1"
                  stroke-dasharray="3 3"
                  points="0,20 300,20"
                />
              </svg>
              <div class="mt-1 flex justify-between font-mono text-[11px] text-[var(--muted)]">
                <span>Oldest</span><span>Latest</span>
              </div>
            </div>
          <% end %>
        </.card>

        <div class="grid gap-3 lg:grid-cols-[1.35fr_0.65fr]">
          <.form
            for={@form}
            id="history-filter-form"
            phx-submit="apply-filters"
            class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)] p-5"
          >
            <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
              Filters
            </h2>
            <div class="mt-4 grid gap-3 sm:grid-cols-2">
              <div class="flex flex-col gap-1.5">
                <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Event id</label>
                <.input
                  field={@form[:event]}
                  type="text"
                  placeholder="100"
                  class="h-10 rounded-[12px] border border-[var(--border)] bg-[var(--surface2)] px-3 text-sm"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Opponent player id</label>
                <.input
                  field={@form[:opponent]}
                  type="text"
                  placeholder="200"
                  class="h-10 rounded-[12px] border border-[var(--border)] bg-[var(--surface2)] px-3 text-sm"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">From</label>
                <.input
                  field={@form[:from]}
                  type="date"
                  class="h-10 rounded-[12px] border border-[var(--border)] bg-[var(--surface2)] px-3 text-sm"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">To</label>
                <.input
                  field={@form[:to]}
                  type="date"
                  class="h-10 rounded-[12px] border border-[var(--border)] bg-[var(--surface2)] px-3 text-sm"
                />
              </div>
              <div class="flex flex-col gap-1.5 sm:col-span-2">
                <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">Game</label>
                <.input
                  field={@form[:game]}
                  type="select"
                  prompt="Any game"
                  options={Enum.map(KusaData.Games.all(), fn g -> {g.short_name, g.slug} end)}
                  class="h-10 rounded-[12px] border border-[var(--border)] bg-[var(--surface2)] px-3 text-sm"
                />
              </div>
            </div>
            <.btn variant="primary" type="submit" class="mt-4 w-full rounded-full">Filter</.btn>
          </.form>

          <.card class="p-5">
            <div class="flex items-center justify-between">
              <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-[var(--muted)]">
                History graph
              </h2>
              <span class="font-mono text-[11px] text-[var(--muted)]">ego network</span>
            </div>
            <div
              id="player-network"
              phx-hook="AtlasHook"
              phx-update="ignore"
              class="atlas-canvas mt-4 h-[260px] w-full overflow-hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface2)]/40"
            >
            </div>
            <p class="mt-3 text-xs text-[var(--muted)]">
              Derived from filtered sets · max 12 opponents
            </p>
          </.card>
        </div>

        <.card class="overflow-hidden p-0">
          <%= if @loading do %>
            <div class="p-4">
              <.skeleton
                :for={_ <- 1..8}
                class="h-12 w-full rounded-[12px] border border-[var(--border)] last:border-b-0"
              />
            </div>
          <% else %>
            <div id="history-rows">
              <div
                :if={@data == nil || @data["sets"] == []}
                class="px-6 py-10 text-center text-[15px] text-[var(--muted)]"
              >
                No matching sets.
              </div>

              <div
                :for={set <- (@data && @data["sets"]) || []}
                class="flex flex-col gap-1 border-b border-[var(--border)]/60 bg-[var(--surface)]/40 px-5 py-3.5 transition-colors last:border-b-0 hover:bg-[var(--surface2)]/50 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
              >
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span class={["size-1.5 shrink-0 rounded-full", result_dot(set, @player_id)]}></span>
                    <span class="truncate text-[15px] font-medium text-[var(--text)]">
                      {opponent_name(set, @player_id)}
                    </span>
                    <%= if opponent_id(set, @player_id) do %>
                      <.link
                        navigate={~p"/player/#{@player_id}/h2h?vs=#{opponent_id(set, @player_id)}"}
                        class="shrink-0 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2 py-0.5 text-xs text-[var(--muted)] transition-colors hover:border-[var(--accent)]/30 hover:text-[var(--accent)]"
                      >
                        vs profile
                      </.link>
                    <% end %>
                  </div>
                  <div class="mt-0.5 truncate text-sm text-[var(--muted)]">
                    {set["fullRoundText"] || "Set"} · {set["event"]["name"]} · {relative_time(
                      set["completedAt"]
                    )}
                  </div>
                </div>
                <span class={[
                  "shrink-0 self-start rounded-full px-2.5 py-1 font-mono text-[13px] font-bold sm:self-auto",
                  score_class(set, @player_id)
                ]}>
                  {set["displayScore"] || "—"}
                </span>
              </div>
            </div>
          <% end %>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  defp sparkline_points(sets, player_id) do
    recent = sets |> Enum.reverse() |> Enum.take(30)
    total = max(length(recent), 1)

    recent
    |> Enum.with_index()
    |> Enum.map(fn {set, idx} ->
      x = if total == 1, do: 0, else: idx * 300 / (total - 1)
      won = set["winnerId"] == our_entrant_id(set, player_id)
      y = if won, do: 10, else: 30
      "#{Float.round(x * 1.0, 1)},#{y}"
    end)
    |> Enum.join(" ")
  end

  defp opponent_name(set, player_id) do
    set
    |> opponent_slot(player_id)
    |> case do
      %{"entrant" => %{"name" => name}} -> name
      _ -> "—"
    end
  end

  defp opponent_id(set, player_id) do
    case opponent_slot(set, player_id) do
      %{"entrant" => %{"participants" => participants}} ->
        Enum.find_value(participants, fn p ->
          case p["user"] do
            %{"player" => %{"id" => id}} -> id
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end

  defp opponent_slot(set, player_id) do
    Enum.find(set["slots"] || [], fn slot ->
      not Enum.any?(slot["entrant"]["participants"] || [], fn p ->
        match?(%{"player" => %{"id" => ^player_id}}, p["user"])
      end)
    end)
  end

  defp result_dot(set, player_id) do
    if set["winnerId"] == our_entrant_id(set, player_id),
      do: "bg-emerald-400",
      else: "bg-rose-400"
  end

  defp our_entrant_id(set, player_id) do
    Enum.find_value(set["slots"] || [], fn slot ->
      if entrant_has_player?(slot, player_id), do: slot["entrant"]["id"]
    end)
  end

  defp entrant_has_player?(slot, player_id) do
    Enum.any?(slot["entrant"]["participants"] || [], fn p ->
      match?(%{"player" => %{"id" => ^player_id}}, p["user"])
    end)
  end

  defp score_class(set, player_id) do
    if set["winnerId"] == our_entrant_id(set, player_id) do
      "bg-emerald-500/15 text-emerald-300"
    else
      "bg-rose-500/15 text-rose-300"
    end
  end

  defp format_count(0), do: "No sets"
  defp format_count(1), do: "1 set"
  defp format_count(total), do: "#{total} sets"

  defp blank(nil), do: nil

  defp blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      v -> v
    end
  end

  defp blank(value), do: value

  defp iso_to_unix(nil), do: nil

  defp iso_to_unix(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()
      _ -> nil
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
