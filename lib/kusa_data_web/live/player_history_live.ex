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
        {:noreply, assign(socket, data: data, error: nil, loading: false, load_ref: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, data: nil, error: reason, loading: false)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/player/#{@player_id}"}>
          Player page
        </.btn>

        <div class="mt-5">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
            Full match history
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-stone-50">
            {if @data, do: @data["gamer_tag"], else: "Player #{@player_id}"}
          </h1>
          <%= if @data do %>
            <p class="mt-1 text-[15px] text-stone-400">
              {format_count(@data["total"])} · {@data["fetched"]} fetched
              <%= if @data["continuation"] do %>
                · truncated at page {@data["continuation"] - 1}
              <% end %>
            </p>
          <% end %>
        </div>

        <.form
          for={@form}
          id="history-filter-form"
          phx-submit="apply-filters"
          class="mt-6 flex flex-wrap items-end gap-3 rounded-xl border border-stone-800 bg-stone-900/40 p-4"
        >
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Event id</label>
            <.input
              field={@form[:event]}
              type="text"
              placeholder="100"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Opponent player id</label>
            <.input
              field={@form[:opponent]}
              type="text"
              placeholder="200"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">From</label>
            <.input
              field={@form[:from]}
              type="date"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">To</label>
            <.input
              field={@form[:to]}
              type="date"
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-[10px] font-semibold uppercase tracking-[0.16em] text-stone-500">Game</label>
            <.input
              field={@form[:game]}
              type="select"
              prompt="Any game"
              options={Enum.map(KusaData.Games.all(), fn g -> {g.short_name, g.slug} end)}
              class="h-10 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
            />
          </div>
          <.btn variant="primary" type="submit" class="rounded-none">Filter</.btn>
        </.form>

        <div class="mt-6 overflow-hidden rounded-xl border border-stone-800/80">
          <%= if @loading do %>
            <div>
              <.skeleton
                :for={_ <- 1..8}
                class="h-12 w-full rounded-none border-b border-stone-800/60 last:border-b-0"
              />
            </div>
          <% else %>
            <div id="history-rows">
              <div
                :if={@data == nil || @data["sets"] == []}
                class="px-6 py-10 text-center text-[15px] text-stone-400"
              >
                No matching sets.
              </div>

              <div
                :for={set <- (@data && @data["sets"]) || []}
                class="flex flex-col gap-1 border-b border-stone-800/70 bg-stone-900/40 px-5 py-3.5 transition-colors last:border-b-0 hover:bg-stone-900/70 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
              >
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span class={["size-1.5 shrink-0 rounded-full", result_dot(set, @player_id)]}></span>
                    <span class="truncate text-[15px] font-medium text-stone-200">
                      {opponent_name(set, @player_id)}
                    </span>
                    <%= if opponent_id(set, @player_id) do %>
                      <.link
                        navigate={~p"/player/#{@player_id}/h2h?vs=#{opponent_id(set, @player_id)}"}
                        class="shrink-0 text-xs text-stone-500 transition-colors hover:text-lime-300"
                      >
                        vs profile
                      </.link>
                    <% end %>
                  </div>
                  <div class="mt-0.5 truncate text-sm text-stone-400">
                    {set["fullRoundText"] || "Set"} · {set["event"]["name"]} · {relative_time(
                      set["completedAt"]
                    )}
                  </div>
                </div>
                <span class={[
                  "shrink-0 self-start rounded-md px-2.5 py-1 font-mono text-[13px] font-bold sm:self-auto",
                  score_class(set, @player_id)
                ]}>
                  {set["displayScore"] || "—"}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
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
      "bg-emerald-500/10 text-emerald-300"
    else
      "bg-rose-500/10 text-rose-300"
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
