defmodule KusaDataWeb.LeagueLive do
  @moduledoc """
  A single owned league: its members, imported tournaments, and season
  standings, plus one-click tournament import by slug.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Leagues

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       league_id: nil,
       league: nil,
       members: [],
       tournaments: [],
       seasons: [],
       season: nil,
       standings: [],
       form: to_form(%{"slug" => ""})
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    league_id = params["id"]
    user = socket.assigns.current_user
    league = if user, do: Leagues.get_owned_league(user, league_id), else: nil

    socket = assign(socket, :league_id, league_id)

    socket =
      if league do
        assign_league_data(socket, league)
      else
        assign(socket,
          league: nil,
          members: [],
          tournaments: [],
          seasons: [],
          season: nil,
          standings: []
        )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("import", %{"slug" => slug}, socket) do
    league = socket.assigns.league

    socket =
      if league do
        case safe_import(league, slug) do
          :ok ->
            socket
            |> assign_league_data(league)
            |> assign(:form, to_form(%{"slug" => ""}))

          :error ->
            put_flash(socket, :error, "Could not import that tournament.")
        end
      else
        socket
      end

    {:noreply, socket}
  end

  defp assign_league_data(socket, league) do
    seasons = safe_seasons(league)
    season = List.last(seasons)
    standings = if season, do: safe_standings(league, season, 3), else: []

    assign(socket,
      league: league,
      members: safe_members(league),
      tournaments: safe_tournaments(league),
      seasons: seasons,
      season: season,
      standings: standings
    )
  end

  defp safe_members(league) do
    case Leagues.members(league) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp safe_tournaments(league) do
    case Leagues.tournaments(league) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp safe_seasons(league) do
    case Leagues.seasons(league) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp safe_standings(league, season, min_tournaments) do
    case Leagues.season_standings(league, season, min_tournaments) do
      {:ok, data} when is_list(data) -> data
      _ -> []
    end
  end

  defp safe_import(league, slug) do
    case Leagues.import_tournament(league, slug) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:leagues}>
      <%= if @league do %>
        <div id={"league-#{@league_id}"} class="flex flex-col gap-10">
          <header class="flex flex-wrap items-end justify-between gap-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.12em] text-faint">League</p>
              <h1 class="mt-1 font-display text-3xl font-bold tracking-tight text-ink">
                {@league.name}
              </h1>
            </div>
            <div class="flex items-center gap-3">
              <.stat label="Members" value={to_string(length(@members))} />
              <.stat label="Tournaments" value={to_string(length(@tournaments))} />
              <.stat label="Seasons" value={to_string(length(@seasons))} />
            </div>
          </header>

          <section>
            <h2 class="font-display text-xl font-semibold text-ink">Members</h2>
            <%= if Enum.empty?(@members) do %>
              <.empty
                class="mt-4"
                icon="hero-user-group"
                title="No members yet"
                description="Import a tournament to pull its players into the league."
              />
            <% else %>
              <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <%= for member <- @members do %>
                  <.link
                    id={"member-#{member.player_id}"}
                    navigate={~p"/player/#{member.player_id}"}
                    class="flex items-center justify-between gap-3 rounded-none border border-line bg-surface px-4 py-3 transition-colors hover:border-accent-line hover:bg-surface-2"
                  >
                    <span class="font-medium text-ink">{member.canonical_tag ||
                      "Player #{member.player_id}"}</span>
                    <.badge variant={:outline}>{to_string(member.player_id)}</.badge>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </section>

          <section>
            <h2 class="font-display text-xl font-semibold text-ink">Tournaments</h2>
            <%= if Enum.empty?(@tournaments) do %>
              <.empty
                class="mt-4"
                icon="hero-trophy"
                title="No tournaments imported"
                description="Use the import form below to add a tournament."
              />
            <% else %>
              <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <%= for t <- @tournaments do %>
                  <.link
                    id={"league-tournament-#{t.tournament_id}"}
                    navigate={~p"/tournament/#{Format.bare_slug(t.tournament_slug)}"}
                    class="flex items-center justify-between gap-3 rounded-none border border-line bg-surface px-4 py-3 transition-colors hover:border-accent-line hover:bg-surface-2"
                  >
                    <span class="font-medium text-ink">{Format.bare_slug(t.tournament_slug)}</span>
                    <.icon name="hero-arrow-right" class="size-4 text-faint" />
                  </.link>
                <% end %>
              </div>
            <% end %>
          </section>

          <section>
            <div class="flex items-end justify-between gap-3">
              <h2 class="font-display text-xl font-semibold text-ink">Season standings</h2>
              <%= if @season do %>
                <.badge variant={:accent}>{@season.name}</.badge>
              <% end %>
            </div>
            <%= if @season do %>
              <p class="mt-1 text-sm text-faint">
                {Format.date(DateTime.to_unix(@season.start_at))} – {Format.date(
                  DateTime.to_unix(@season.end_at)
                )}
              </p>
            <% end %>
            <%= if Enum.empty?(@standings) do %>
              <.empty
                class="mt-4"
                icon="hero-chart-bar"
                title="No standings yet"
                description="Add members and import tournaments within the season window."
              />
            <% else %>
              <.table class="mt-4">
                <thead>
                  <tr class="text-left text-xs uppercase tracking-[0.08em] text-muted">
                    <th class="px-4 py-3 font-semibold">Rank</th>
                    <th class="px-4 py-3 font-semibold">Player</th>
                    <th class="px-4 py-3 text-right font-semibold">Points</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {ranking, idx} <- Enum.with_index(@standings) do %>
                    <tr class="border-t border-line transition-colors hover:bg-surface-2">
                      <td class="px-4 py-3 text-muted">{idx + 1}</td>
                      <td class="px-4 py-3 text-ink">{ranking["gamer_tag"]}</td>
                      <td class="px-4 py-3 text-right font-display font-semibold text-accent">
                        {ranking["rating"]}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </.table>
            <% end %>
          </section>

          <section class="rounded-none border border-line bg-surface p-6">
            <h2 class="font-display text-lg font-semibold text-ink">Import tournament</h2>
            <p class="mt-1 text-sm text-muted">Add a start.gg tournament to this league by slug.</p>
            <.form
              for={@form}
              id="league-import-form"
              phx-submit="import"
              class="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end"
            >
              <.input
                field={@form[:slug]}
                id="league-import-slug"
                label="Tournament slug"
                placeholder="tournament/slug"
                class="flex-1"
              />
              <.button type="submit" variant={:primary}>Import</.button>
            </.form>
          </section>
        </div>
      <% else %>
        <div id={"league-#{@league_id}"}>
          <.empty
            icon="hero-exclamation-triangle"
            title="League not found"
            description="This league doesn't exist or isn't yours."
          />
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
