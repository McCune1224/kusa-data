defmodule KusaDataWeb.PlayerTrendLive do
  @moduledoc """
  Monthly performance trend for a player: win rate plus best placement per month.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       player_id: nil,
       gamer_tag: nil,
       buckets: [],
       total_sets: 0,
       total_wins: 0,
       overall_win_rate: 0.0
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    player_id = parse_id(Map.get(params, "id"))
    data = safe_trend(player_id)

    buckets = Enum.sort_by(data["buckets"] || [], & &1["month"], :desc)

    {total_sets, total_wins} =
      Enum.reduce(buckets, {0, 0}, fn bucket, {sets, wins} ->
        {sets + (bucket["sets"] || 0), wins + (bucket["wins"] || 0)}
      end)

    overall_win_rate =
      if total_sets > 0, do: round(total_wins * 1000 / total_sets) / 10, else: 0.0

    {:noreply,
     assign(socket,
       player_id: player_id,
       gamer_tag: data["gamer_tag"],
       buckets: buckets,
       total_sets: total_sets,
       total_wins: total_wins,
       overall_win_rate: overall_win_rate
     )}
  end

  defp parse_id(nil), do: nil

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_id(id), do: id

  defp safe_trend(nil), do: %{"buckets" => []}

  defp safe_trend(player_id) do
    case KusaData.Players.trend(player_id, %{}) do
      {:ok, data, _} -> data
      {:error, _} -> %{"player_id" => player_id, "buckets" => []}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:players}>
      <div id={"player-trend-#{@player_id}"} class="flex flex-col gap-8">
        <header class="flex flex-col gap-2">
          <div class="flex items-center gap-2 text-sm text-muted">
            <%= if is_integer(@player_id) do %>
              <.link
                navigate={~p"/player/#{@player_id}"}
                class="inline-flex items-center gap-1.5 transition-colors hover:text-accent"
              >
                <span class="hero-arrow-left size-4"></span>
                {if @gamer_tag, do: @gamer_tag, else: "Player ##{@player_id}"}
              </.link>
            <% else %>
              <span>{if @gamer_tag, do: @gamer_tag, else: "Player"}</span>
            <% end %>
          </div>
          <h1 class="font-display text-3xl font-bold tracking-tight text-ink">Performance trend</h1>
          <p class="text-sm text-muted">
            Monthly win rate and best placement across recent events.
          </p>
        </header>

        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <.stat label="Months tracked" value={to_string(length(@buckets))} />
          <.stat label="Sets played" value={to_string(@total_sets)} />
          <.stat label="Wins" value={to_string(@total_wins)} />
          <.stat label="Overall win rate" value={Format.percent(@overall_win_rate)} />
        </section>

        <%= if Enum.empty?(@buckets) do %>
          <.empty
            icon="hero-chart-bar"
            title="No trend data yet"
            description="This player doesn't have any completed sets in the recent window."
          />
        <% else %>
          <.table>
            <table>
              <thead>
                <tr class="border-b border-line text-left text-xs uppercase tracking-[0.08em] text-muted">
                  <th class="px-4 py-3 font-semibold">Month</th>
                  <th class="px-4 py-3 font-semibold">Sets</th>
                  <th class="px-4 py-3 font-semibold">Record</th>
                  <th class="px-4 py-3 font-semibold">Win rate</th>
                  <th class="px-4 py-3 font-semibold">Best placement</th>
                </tr>
              </thead>
              <tbody>
                <%= for bucket <- @buckets do %>
                  <tr class="border-b border-line transition-colors last:border-0 hover:bg-surface-2">
                    <td class="px-4 py-3 font-medium text-ink">{bucket["month"]}</td>
                    <td class="px-4 py-3 text-muted">{bucket["sets"]}</td>
                    <td class="px-4 py-3 text-muted">{"#{bucket["wins"]}–#{bucket["losses"]}"}</td>
                    <td class="px-4 py-3">
                      <div class="flex items-center gap-3">
                        <div class="h-2 w-32 overflow-hidden rounded-pill bg-surface-2">
                          <div
                            class="h-full rounded-pill bg-accent transition-all"
                            style={"width: #{bucket["win_rate"] || 0}%"}
                          >
                          </div>
                        </div>
                        <span class="text-xs font-medium text-muted">
                          {Format.percent(bucket["win_rate"] || 0)}
                        </span>
                      </div>
                    </td>
                    <td class="px-4 py-3">
                      <%= if bucket["best_placement"] do %>
                        <.badge variant={:accent}>{bucket["best_placement"]}</.badge>
                      <% else %>
                        <span class="text-faint">—</span>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </.table>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
