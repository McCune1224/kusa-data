defmodule KusaDataWeb.PlayerLive do
  @moduledoc """
  Player profile screen: identity header, career stats, quick links to the
  history / trend / head-to-head sub-pages, and recent placements.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, player_id: nil, game: nil, player: %{}, card: %{})}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    player_id = parse_id(id)
    game = Map.get(params, "game")

    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:game, game)
      |> assign(:player, safe_profile(player_id))
      |> assign(:card, safe_card(player_id, game))

    {:noreply, socket}
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> id
    end
  end

  defp parse_id(id), do: id

  defp safe_profile(player_id) do
    case KusaData.Players.profile(player_id) do
      {:ok, data, _} -> data
      {:error, _} -> %{}
    end
  end

  defp safe_card(player_id, game) do
    case KusaData.Players.card(player_id, game) do
      {:ok, data, _} -> data
      {:error, _} -> %{}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:players}>
      <div id={"player-#{@player_id}"} class="space-y-8">
        <%!-- Identity header --%>
        <section class="rounded-none border border-line bg-surface px-6 py-8">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="flex items-center gap-4">
              <%= if @player["avatar_url"] do %>
                <img
                  src={@player["avatar_url"]}
                  alt={@player["gamer_tag"] || "Player"}
                  class="size-16 rounded-none border border-line object-cover"
                />
              <% else %>
                <div class="flex size-16 items-center justify-center rounded-none border border-line bg-surface-2 font-display text-2xl font-bold text-accent">
                  {String.first(@player["gamer_tag"] || "P")}
                </div>
              <% end %>
              <div>
                <div class="flex items-center gap-2">
                  <h1 class="font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
                    {@player["gamer_tag"] || "Player"}
                  </h1>
                  <%= if @player["prefix"] do %>
                    <.badge variant={:accent}>{@player["prefix"]}</.badge>
                  <% end %>
                </div>
                <%= if @player["location"] do %>
                  <p class="mt-1 flex items-center gap-1.5 text-sm text-muted">
                    <span class="hero-map-pin size-4"></span> {@player["location"]}
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </section>

        <%!-- Career stats --%>
        <section class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <.stat
            label="Win rate"
            value={Format.percent(@card["win_rate"])}
            sub={"#{@card["wins"] || 0}W / #{@card["losses"] || 0}L"}
          />
          <.stat label="Wins" value={to_string(@card["wins"] || 0)} />
          <.stat label="Losses" value={to_string(@card["losses"] || 0)} />
          <.stat label="Sets seen" value={to_string(@card["sets_seen"] || 0)} />
          <.stat label="Events entered" value={to_string(@card["events_entered"] || 0)} />
        </section>

        <%!-- Quick links to sub-pages --%>
        <section class="flex flex-wrap gap-3">
          <.link
            navigate={~p"/player/#{@player_id}/history"}
            class="rounded-none border border-line bg-surface px-4 py-2 text-sm font-medium text-ink transition-colors hover:border-accent-line hover:text-accent"
          >
            Set history
          </.link>
          <.link
            navigate={~p"/player/#{@player_id}/trend"}
            class="rounded-none border border-line bg-surface px-4 py-2 text-sm font-medium text-ink transition-colors hover:border-accent-line hover:text-accent"
          >
            Trend
          </.link>
          <.link
            navigate={~p"/player/#{@player_id}/h2h"}
            class="rounded-none border border-line bg-surface px-4 py-2 text-sm font-medium text-ink transition-colors hover:border-accent-line hover:text-accent"
          >
            Head-to-head
          </.link>
        </section>

        <%!-- Recent placements --%>
        <section>
          <h2 class="font-display text-xl font-semibold text-ink">Recent placements</h2>
          <%= if Enum.empty?(@card["finishes"] || []) do %>
            <.empty
              class="mt-6"
              icon="hero-trophy"
              title="No placements yet"
              description="Results will appear here once this player has entered events."
            />
          <% else %>
            <.table class="mt-4">
              <table>
                <thead>
                  <tr class="border-b border-line text-left text-xs uppercase tracking-[0.08em] text-muted">
                    <th class="px-4 py-3 font-medium">Event</th>
                    <th class="px-4 py-3 font-medium">Placement</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for finish <- @card["finishes"] do %>
                    <tr class="border-b border-line/60 transition-colors hover:bg-surface-2">
                      <td class="px-4 py-3">
                        <.link
                          navigate={~p"/event/#{finish["event_id"]}"}
                          class="text-ink transition-colors hover:text-accent"
                        >
                          Event #{finish["event_id"]}
                        </.link>
                      </td>
                      <td class="px-4 py-3 text-muted">{finish["placement"]}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </.table>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
