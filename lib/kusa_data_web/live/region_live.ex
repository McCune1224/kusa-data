defmodule KusaDataWeb.RegionLive do
  @moduledoc """
  Browse tournaments by region: an index of available regions plus a
  per-region grid of tournaments.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       view: :index,
       regions: [],
       country: nil,
       state: nil,
       tournaments: []
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    if Map.has_key?(params, "country") do
      country = params["country"]
      state = Map.get(params, "state", nil)

      tournaments =
        safe_browse(%{mode: :region, country: country, state: state})["tournaments"] || []

      {:noreply,
       assign(socket, view: :region, country: country, state: state, tournaments: tournaments)}
    else
      {:noreply, assign(socket, view: :index, regions: safe_regions())}
    end
  end

  defp safe_regions do
    case KusaData.Tournaments.regions() do
      {:ok, regions, _cache} -> regions
      {:error, _reason} -> []
    end
  end

  defp safe_browse(query) do
    case KusaData.Tournaments.browse(query) do
      {:ok, page, _cache} -> page
      {:error, _reason} -> %{"tournaments" => []}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <%= if @view == :region do %>
        <section id={"region-#{@country}-#{@state}"} class="mx-auto max-w-7xl">
          <div class="flex items-end justify-between gap-4">
            <div>
              <h1 class="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                {@country}
              </h1>
              <%= if @state do %>
                <p class="mt-1 text-sm text-muted">{@state}</p>
              <% end %>
            </div>
            <.link
              navigate={~p"/regions"}
              class="text-sm font-medium text-accent transition-colors hover:underline"
            >
              All regions
            </.link>
          </div>

          <%= if Enum.empty?(@tournaments) do %>
            <.empty
              class="mt-8"
              icon="hero-map"
              title="No tournaments in this region"
              description="Check back later — the scene moves fast."
            />
          <% else %>
            <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for tournament <- @tournaments do %>
                <.tournament_card tournament={tournament} />
              <% end %>
            </div>
          <% end %>
        </section>
      <% else %>
        <section id="regions-live" class="mx-auto max-w-7xl">
          <div class="flex items-end justify-between gap-4">
            <div>
              <h1 class="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                Tournaments by region
              </h1>
              <p class="mt-1 text-sm text-muted">
                Browse the scene by country and state, best-attended first.
              </p>
            </div>
            <%= if not Enum.empty?(@regions) do %>
              <span class="hidden text-sm text-faint sm:inline">
                {length(@regions)} regions
              </span>
            <% end %>
          </div>

          <%= if Enum.empty?(@regions) do %>
            <.empty
              class="mt-8"
              icon="hero-map"
              title="No regions available yet"
              description="Region data is derived from recent tournaments."
            />
          <% else %>
            <.table class="mt-6">
              <thead>
                <tr class="text-left text-xs font-semibold uppercase tracking-[0.08em] text-muted">
                  <th class="px-4 py-3 font-semibold">Country</th>
                  <th class="px-4 py-3 font-semibold">State</th>
                  <th class="px-4 py-3 text-right font-semibold">Tournaments</th>
                  <th class="px-4 py-3 text-right font-semibold">Attendees</th>
                </tr>
              </thead>
              <tbody>
                <%= for region <- @regions do %>
                  <tr class="border-t border-line transition-colors hover:bg-surface-2">
                    <td class="px-4 py-3">
                      <%= if region["state"] do %>
                        <.link
                          navigate={~p"/region/#{region["country"]}/#{region["state"]}"}
                          class="font-medium text-ink transition-colors hover:text-accent"
                        >
                          {region["country"]}
                          <span class="text-muted"> · {region["state"]}</span>
                        </.link>
                      <% else %>
                        <span class="font-medium text-ink">
                          {region["country"]}
                        </span>
                      <% end %>
                    </td>
                    <td class="px-4 py-3 text-muted">{region["state"] || "—"}</td>
                    <td class="px-4 py-3 text-right text-ink">{region["tournaments"]}</td>
                    <td class="px-4 py-3 text-right text-muted">{region["attendees"]}</td>
                  </tr>
                <% end %>
              </tbody>
            </.table>
          <% end %>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
