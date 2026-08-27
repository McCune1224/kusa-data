defmodule KusaDataWeb.PlayerHistoryLive do
  @moduledoc """
  Filterable set-history table for a single player.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       player_id: nil,
       gamer_tag: nil,
       sets: [],
       total: 0,
       filters: %{},
       form: to_form(%{}, as: :filter)
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    player_id = parse_id(id)
    {:noreply, load(socket, player_id, %{})}
  end

  @impl true
  def handle_event("filter", %{"filter" => params}, socket) do
    player_id = socket.assigns.player_id
    filters = filters_from_params(params)
    {:noreply, load(socket, player_id, filters)}
  end

  defp load(socket, player_id, filters) when is_integer(player_id) do
    data = safe_history(player_id, filters)

    socket
    |> assign(:player_id, player_id)
    |> assign(:gamer_tag, Map.get(data, "gamer_tag"))
    |> assign(:sets, Map.get(data, "sets", []))
    |> assign(:total, Map.get(data, "total", 0))
    |> assign(:filters, filters)
    |> assign_filter_form(filters)
  end

  defp load(socket, _player_id, _filters) do
    socket
    |> assign(:player_id, nil)
    |> assign(:gamer_tag, nil)
    |> assign(:sets, [])
    |> assign(:total, 0)
    |> assign(:filters, %{})
    |> assign_filter_form(%{})
  end

  defp assign_filter_form(socket, filters) do
    values = %{
      "game" => Map.get(filters, :game, ""),
      "opponent" => Map.get(filters, :opponent, "")
    }

    assign(socket, :form, to_form(values, as: :filter))
  end

  defp safe_history(player_id, filters) do
    case KusaData.Players.history(player_id, filters) do
      {:ok, data, _} -> data
      {:error, _} -> %{}
    end
  end

  defp filters_from_params(params) do
    %{}
    |> put_opt(:game, Map.get(params, "game"))
    |> put_opt(:opponent, parse_id(Map.get(params, "opponent")))
  end

  defp put_opt(map, _key, nil), do: map
  defp put_opt(map, _key, value) when is_binary(value) and value == "", do: map
  defp put_opt(map, key, value), do: Map.put(map, key, value)

  defp parse_id(nil), do: nil

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_id(value) when is_integer(value), do: value
  defp parse_id(_value), do: nil

  # --- presentation helpers -------------------------------------------------

  defp event_name(set) do
    (set["event"] || %{})["name"] || "—"
  end

  defp event_id(set) do
    (set["event"] || %{})["id"]
  end

  defp round_text(set) do
    set["fullRoundText"] || "—"
  end

  defp display_score(set) do
    set["displayScore"] || "—"
  end

  defp opponent_name(set, player_id) do
    opponent =
      Enum.find(set["slots"] || [], fn slot ->
        not Enum.any?((slot["entrant"] || %{})["participants"] || [], fn p ->
          match?(%{"user" => %{"player" => %{"id" => ^player_id}}}, p)
        end)
      end)

    case opponent do
      nil -> "—"
      slot -> (slot["entrant"] || %{})["name"] || "—"
    end
  end

  defp player_won?(set, player_id) when is_integer(player_id) do
    Enum.any?(set["slots"] || [], fn slot ->
      entrant = slot["entrant"] || %{}

      entrant["id"] == set["winnerId"] and
        Enum.any?(entrant["participants"] || [], fn p ->
          match?(%{"user" => %{"player" => %{"id" => ^player_id}}}, p)
        end)
    end)
  end

  defp player_won?(_set, _player_id), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:players}>
      <div id={"player-history-#{@player_id}"} class="flex flex-col gap-8">
        <header class="flex flex-col gap-3">
          <div class="flex items-center gap-2 text-sm text-muted">
            <%= if @player_id do %>
              <.link navigate={~p"/player/#{@player_id}"} class="transition-colors hover:text-accent">
                ← Back to profile
              </.link>
            <% end %>
          </div>
          <div class="flex flex-wrap items-end justify-between gap-4">
            <div>
              <h1 class="font-display text-3xl font-bold tracking-tight text-ink">
                {@gamer_tag || "Player"} <span class="text-faint">· History</span>
              </h1>
              <p class="mt-1 text-sm text-muted">
                Every set on record, filterable by game and opponent.
              </p>
            </div>
            <.stat class="min-w-28" label="Sets" value={to_string(@total)} />
          </div>
        </header>

        <.card class="p-5">
          <.form
            for={@form}
            id="history-filter-form"
            phx-submit="filter"
            class="flex flex-wrap items-end gap-4"
          >
            <.input
              field={@form[:game]}
              label="Game slug"
              placeholder="melee"
              class="sm:w-48"
            />
            <.input
              field={@form[:opponent]}
              label="Opponent ID"
              placeholder="e.g. 200"
              class="sm:w-44"
            />
            <.button type="submit" variant="primary" size="sm">Apply filters</.button>
          </.form>
        </.card>

        <%= if Enum.empty?(@sets) do %>
          <.empty
            icon="hero-clock"
            title="No sets found"
            description="This player has no recorded sets for the current filters."
          />
        <% else %>
          <.table>
            <thead>
              <tr class="border-b border-line text-left text-xs uppercase tracking-[0.08em] text-muted">
                <th class="px-4 py-3 font-semibold">Event</th>
                <th class="px-4 py-3 font-semibold">Round</th>
                <th class="px-4 py-3 font-semibold">Opponent</th>
                <th class="px-4 py-3 font-semibold">Result</th>
                <th class="px-4 py-3 font-semibold">Score</th>
                <th class="px-4 py-3 font-semibold">Date</th>
              </tr>
            </thead>
            <tbody>
              <%= for set <- @sets do %>
                <tr class="border-b border-line transition-colors last:border-0 hover:bg-surface-2">
                  <%= if eid = event_id(set) do %>
                    <td class="px-4 py-3">
                      <.link
                        navigate={~p"/event/#{eid}"}
                        class="font-medium text-ink transition-colors hover:text-accent"
                      >
                        {event_name(set)}
                      </.link>
                    </td>
                  <% else %>
                    <td class="px-4 py-3 text-muted">{event_name(set)}</td>
                  <% end %>
                  <td class="px-4 py-3 text-muted">{round_text(set)}</td>
                  <td class="px-4 py-3 text-ink">{opponent_name(set, @player_id)}</td>
                  <td class="px-4 py-3">
                    <%= if player_won?(set, @player_id) do %>
                      <.badge variant={:accent}>W</.badge>
                    <% else %>
                      <.badge variant={:danger}>L</.badge>
                    <% end %>
                  </td>
                  <td class="px-4 py-3 tabular-nums text-muted">{display_score(set)}</td>
                  <td class="px-4 py-3 text-muted">
                    {Format.date(set["completedAt"])}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </.table>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
