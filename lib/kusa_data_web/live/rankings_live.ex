defmodule KusaDataWeb.RankingsLive do
  @moduledoc """
  Region/game/season power rankings.

  Reads the deterministic Elo table produced by `KusaData.Rankings.rank/1`
  and renders it as a ranked table. A small filter form lets the user scope
  by region (`country`/`state`) and game; submitting re-queries the engine
  via `handle_event`.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Rankings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       filters: %{},
       form: to_form(%{}, as: :filters),
       rankings: [],
       meta: %{}
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load(socket, %{})}
  end

  @impl true
  def handle_event("filter", %{"filters" => raw}, socket) do
    filters = %{
      "country" => blank_to_nil(raw["country"]),
      "state" => blank_to_nil(raw["state"]),
      "game" => blank_to_nil(raw["game"])
    }

    socket =
      socket
      |> load(%{country: filters["country"], state: filters["state"], game: filters["game"]})
      |> assign(filters: filters, form: to_form(filters, as: :filters))

    {:noreply, socket}
  end

  defp load(socket, opts) do
    result = safe_rank(opts)
    rankings = Map.get(result, "rankings", []) || []
    meta = Map.take(result, ["tournaments", "players_scanned"])

    assign(socket, rankings: rankings, meta: meta)
  end

  defp safe_rank(opts) do
    case Rankings.rank(opts) do
      {:ok, data, _} -> data
      {:error, _} -> %{}
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(_value), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:rankings}>
      <div id="rankings-live" class="flex flex-col gap-8">
        <header class="flex flex-col gap-3">
          <span class="inline-flex w-fit items-center gap-2 rounded-none border border-accent-line bg-accent-soft px-3 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-accent">
            <span class="hero-trophy size-3.5"></span> Power rankings
          </span>
          <h1 class="font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
            Melee <span class="text-accent">rankings</span>
          </h1>
          <p class="max-w-2xl text-base text-muted">
            A deterministic Elo table built from recent bracket results. Players are
            scored on completed sets, weighted by recency, across the scoped scene.
          </p>
        </header>

        <.card class="px-5 py-5">
          <.form for={@form} id="rankings-filter-form" phx-submit="filter" class="flex flex-col gap-4">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <.input
                field={@form[:country]}
                id="filter-country"
                label="Country"
                placeholder="e.g. US"
              />
              <.input
                field={@form[:state]}
                id="filter-state"
                label="State / region"
                placeholder="e.g. CA"
              />
              <.input
                field={@form[:game]}
                id="filter-game"
                label="Game"
                placeholder="e.g. melee"
              />
            </div>
            <div class="flex items-center gap-3">
              <.button type="submit" variant="primary" size="md">Apply filters</.button>
              <.link
                navigate={~p"/rankings"}
                class="text-sm font-medium text-muted transition-colors hover:text-accent"
              >
                Reset
              </.link>
            </div>
          </.form>
        </.card>

        <div class="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-muted">
          <span>
            <span class="font-semibold text-ink">{Map.get(@meta, "tournaments", 0)}</span>
            tournaments scanned
          </span>
          <span>
            <span class="font-semibold text-ink">{Map.get(@meta, "players_scanned", 0)}</span>
            players scanned
          </span>
        </div>

        <%= if Enum.empty?(@rankings) do %>
          <.empty
            class="mt-2"
            icon="hero-trophy"
            title="No rankings yet"
            description="Try adjusting the region or game filters, or check back once more results are in."
          />
        <% else %>
          <.table>
            <thead>
              <tr class="border-b border-line text-left text-xs font-semibold uppercase tracking-[0.08em] text-faint">
                <th class="px-4 py-3">Rank</th>
                <th class="px-4 py-3">Player</th>
                <th class="px-4 py-3 text-right">Rating</th>
                <th class="px-4 py-3 text-right">W–L</th>
                <th class="px-4 py-3 text-right">Tournaments</th>
              </tr>
            </thead>
            <tbody>
              <%= for {player, rank} <- Enum.with_index(@rankings, 1) do %>
                <tr class="border-b border-line/60 transition-colors hover:bg-surface-2">
                  <td class="px-4 py-3 font-display text-lg font-semibold text-ink">{rank}</td>
                  <td class="px-4 py-3">
                    <.link
                      navigate={~p"/player/#{player["player_id"]}"}
                      class="font-medium text-ink transition-colors hover:text-accent"
                    >
                      {player["gamer_tag"]}
                    </.link>
                  </td>
                  <td class="px-4 py-3 text-right font-display font-semibold text-accent">
                    {player["rating"]}
                  </td>
                  <td class="px-4 py-3 text-right text-muted">
                    {player["wins"]}&ndash;{player["losses"]}
                  </td>
                  <td class="px-4 py-3 text-right text-muted">{player["tournaments"]}</td>
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
