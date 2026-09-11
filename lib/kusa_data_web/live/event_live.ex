defmodule KusaDataWeb.EventLive do
  @moduledoc """
  Single-event bracket overview: header card, recap metric tiles, and final
  standings with per-player win-loss pulled from the joined analytics.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Events
  alias KusaData.Stats.BracketEngine

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       event_id: nil,
       event: nil,
       stat_tiles: [],
       standings: [],
       root_id: "event-unknown",
       loading: false
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    event_id = parse_event_id(params["event"])

    socket =
      if event_id do
        socket
        |> assign(event_id: event_id, root_id: "event-#{event_id}", loading: true)
        |> start_async(:event_task, fn -> fetch_event_data(event_id) end)
      else
        assign(socket,
          event_id: nil,
          event: nil,
          stat_tiles: [],
          standings: [],
          tournament_name: nil,
          tournament_path: nil,
          game: nil,
          entrant_count: nil,
          root_id: "event-unknown"
        )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_async(:event_task, {:ok, data}, socket) do
    %{
      event: event,
      standings: standings,
      recap: recap,
      tournament_path: tournament_path,
      tournament_name: tournament_name,
      game: game,
      entrant_count: entrant_count
    } = data

    {:noreply,
     assign(socket,
       event: event,
       stat_tiles: stat_tiles(recap),
       standings: standings,
       tournament_name: tournament_name,
       tournament_path: tournament_path,
       game: game,
       entrant_count: entrant_count,
       loading: false
     )}
  end

  def handle_async(_name, {:error, _reason}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  defp fetch_event_data(event_id) do
    event = safe_get(event_id)
    results = safe_results(event_id)
    analytics = safe_analytics(event_id, event: event, results: results)
    analysis = Map.get(analytics, "analysis", %{})
    recap = safe_recap(analysis)

    wl_by_entrant =
      analysis
      |> Map.get("entrants", [])
      |> Enum.map(fn e -> {e["entrant_id"], {e["wins"], e["losses"]}} end)
      |> Map.new()

    standings =
      results
      |> Enum.map(fn s ->
        {wins, losses} = Map.get(wl_by_entrant, s["entrant_id"], {nil, nil})
        Map.merge(s, %{"wins" => wins, "losses" => losses})
      end)

    {tournament_slug, tournament_name} = tournament_of(event)
    tournament_path = tournament_path(tournament_slug)

    %{
      event: event,
      standings: standings,
      recap: recap,
      tournament_name: tournament_name,
      tournament_path: tournament_path,
      game: game_of(event),
      entrant_count: event && event["numEntrants"]
    }
  end

  defp parse_event_id(param) when is_binary(param) do
    case Integer.parse(param) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_event_id(_), do: nil

  defp safe_get(event_id) do
    case Events.get(event_id) do
      {:ok, event, _} -> event
      {:error, _} -> nil
    end
  end

  defp safe_results(event_id) do
    case Events.results(event_id) do
      {:ok, standings, _} -> standings
      {:error, _} -> []
    end
  end

  defp safe_analytics(event_id, opts) do
    case Events.analytics(event_id, opts) do
      {:ok, analytics, _} -> analytics
      {:error, _} -> %{"analysis" => %{}}
    end
  end

  defp safe_recap(analysis) when is_map(analysis) and map_size(analysis) > 0 do
    BracketEngine.recap(analysis)
  end

  defp safe_recap(_), do: %{}

  defp tournament_of(%{} = event) do
    case event["tournament"] do
      %{} = t -> {t["slug"], t["name"]}
      _ -> {nil, nil}
    end
  end

  defp tournament_of(_), do: {nil, nil}

  defp tournament_path(nil), do: nil

  defp tournament_path(slug) do
    ~p"/tournament/#{Format.bare_slug(slug)}"
  end

  defp game_of(%{} = event) do
    case event["videogame"] do
      %{} = vg -> vg["name"]
      _ -> nil
    end
  end

  defp game_of(_), do: nil

  defp stat_tiles(recap) do
    [
      %{label: "Entrants", value: format_metric(recap["entrant_count"])},
      %{label: "Matches", value: format_metric(recap["match_count"])},
      %{label: "Avg sets/entrant", value: format_metric(recap["avg_sets_per_entrant"])},
      %{label: "DQ rate", value: dq_rate_value(recap["dq_rate"])}
    ]
  end

  defp format_metric(nil), do: "—"
  defp format_metric(value) when is_number(value), do: to_string(value)

  defp dq_rate_value(nil), do: "—"
  defp dq_rate_value(value) when is_number(value), do: Format.percent(value)

  defp format_wl(nil, _), do: "—"
  defp format_wl(_, nil), do: "—"
  defp format_wl(wins, losses), do: "#{wins}–#{losses}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id={@root_id} class="flex flex-col gap-8">
        <%= if @loading do %>
          <section class="rounded-none border border-line bg-surface p-6 sm:p-8">
            <div class="flex flex-col gap-4">
              <div class="h-8 w-64 animate-pulse rounded bg-surface-2" />
              <div class="h-4 w-40 animate-pulse rounded bg-surface-2" />
            </div>
          </section>
          <section class="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <%= for _ <- 1..4 do %>
              <div class="h-20 animate-pulse rounded-none border border-line bg-surface" />
            <% end %>
          </section>
        <% else %>
          <%= if @event do %>
            <section class="rounded-none border border-line bg-surface p-6 sm:p-8">
              <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div class="flex flex-col gap-2">
                  <h1 class="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                    {@event["name"]}
                  </h1>
                  <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted">
                    <%= if @game do %>
                      <.badge variant={:accent}>{@game}</.badge>
                    <% end %>
                    <%= if @entrant_count do %>
                      <span><span class="text-ink">{@entrant_count}</span> entrants</span>
                    <% end %>
                    <%= if @event["state"] do %>
                      <span class="text-faint">·</span>
                      <span>{@event["state"]}</span>
                    <% end %>
                  </div>
                </div>
                <%= if @tournament_path do %>
                  <.link
                    navigate={@tournament_path}
                    class="shrink-0 rounded-none border border-line bg-surface-2 px-3 py-1.5 text-sm font-medium text-muted transition-colors hover:border-accent-line hover:text-accent"
                  >
                    ← {@tournament_name || "Tournament"}
                  </.link>
                <% end %>
              </div>
            </section>

            <section class="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <%= for tile <- @stat_tiles do %>
                <.stat label={tile["label"]} value={tile["value"]} />
              <% end %>
            </section>

            <section class="flex flex-col gap-3">
              <h2 class="font-display text-xl font-semibold text-ink">Final standings</h2>
              <%= if Enum.empty?(@standings) do %>
                <.empty
                  class="rounded-none border border-line bg-surface"
                  icon="hero-trophy"
                  title="No standings yet"
                  description="Results will appear here once the bracket is posted."
                />
              <% else %>
                <.table>
                  <thead>
                    <tr class="border-b border-line text-left text-xs font-semibold uppercase tracking-[0.08em] text-muted">
                      <th class="px-4 py-3">Placement</th>
                      <th class="px-4 py-3">Player</th>
                      <th class="px-4 py-3 text-right">W-L</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for s <- @standings do %>
                      <tr class="border-b border-line transition-colors last:border-0 hover:bg-surface-2">
                        <td class="px-4 py-3 font-semibold text-ink">{s["placement"]}</td>
                        <td class="px-4 py-3 text-ink">
                          <%= if s["player_id"] do %>
                            <.link
                              navigate={~p"/player/#{s["player_id"]}"}
                              class="font-medium text-accent transition-colors hover:underline"
                            >
                              {s["name"] || "—"}
                            </.link>
                          <% else %>
                            <span class="text-muted">{s["name"] || "—"}</span>
                          <% end %>
                        </td>
                        <td class="px-4 py-3 text-right tabular-nums text-muted">
                          {format_wl(s["wins"], s["losses"])}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </.table>
              <% end %>
            </section>
          <% else %>
            <.empty
              class="rounded-none border border-line bg-surface"
              icon="hero-x-circle"
              title="Event not found"
              description="We couldn't load this event. Check the link and try again."
            />
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
