defmodule KusaDataWeb.GameLive do
  @moduledoc """
  Per-game tournament directory: `/game/:game`.

  Looks a game up by its slug and shows the tournaments start.gg has for it.
  When the slug is missing or unknown, the page falls back to a directory of
  every known game, each linking to its own `/game/<slug>` page.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:game, nil)
     |> assign(:slug, "all")
     |> assign(:tournaments, [])
     |> assign(:all_games, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    slug = Map.get(params, "game")

    socket =
      case safe_game(slug) do
        nil ->
          socket
          |> assign(:game, nil)
          |> assign(:slug, "all")
          |> assign(:tournaments, [])
          |> assign(:all_games, safe_all_games())

        game ->
          socket
          |> assign(:game, game)
          |> assign(:slug, game.slug)
          |> assign(:tournaments, safe_tournaments(game.slug))
          |> assign(:all_games, [])
      end

    {:noreply, socket}
  end

  defp safe_game(nil), do: nil
  defp safe_game(slug) when is_binary(slug), do: KusaData.Games.by_slug(slug)
  defp safe_game(_), do: nil

  defp safe_all_games, do: KusaData.Games.all()

  defp safe_tournaments(slug) do
    case KusaData.Tournaments.browse(%{games: [slug]}) do
      {:ok, page, _cache} -> page["tournaments"] || []
      {:error, _reason} -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id={"game-#{@slug}"} class="flex flex-col gap-8">
        <%= if @game do %>
          <section class="rounded-none border border-line bg-surface px-6 py-8 sm:px-8">
            <div class="flex flex-wrap items-center gap-3">
              <h1 class="font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
                {@game.name}
              </h1>
              <.badge variant={:accent}>{@game.short_name}</.badge>
            </div>
            <p class="mt-2 text-sm text-muted">
              Tournaments for <span class="text-ink">{@game.name}</span> on start.gg.
            </p>
          </section>

          <%= if Enum.empty?(@tournaments) do %>
            <.empty
              class="rounded-none border border-line bg-surface"
              icon="hero-calendar"
              title="No tournaments found"
              description={"We couldn't find any upcoming tournaments for #{@game.name} right now."}
            />
          <% else %>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for tournament <- @tournaments do %>
                <.tournament_card tournament={tournament} />
              <% end %>
            </div>
          <% end %>
        <% else %>
          <section class="rounded-none border border-line bg-surface px-6 py-8 sm:px-8">
            <h1 class="font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
              Browse by game
            </h1>
            <p class="mt-2 text-sm text-muted">
              Pick a game to see its tournaments across the scene.
            </p>
          </section>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for g <- @all_games do %>
              <.link
                id={"game-pick-#{g.slug}"}
                navigate={~p"/game/#{g.slug}"}
                class={[
                  "group flex items-center justify-between gap-4 rounded-none border border-line bg-surface p-5",
                  "transition-all duration-150 hover:border-accent-line hover:bg-surface-2"
                ]}
              >
                <div class="min-w-0">
                  <h3 class="font-display text-lg font-semibold leading-tight text-ink transition-colors group-hover:text-accent">
                    {g.name}
                  </h3>
                  <p class="truncate text-sm text-muted">{g.short_name}</p>
                </div>
                <.icon
                  name="hero-chevron-right"
                  class="size-5 shrink-0 text-faint transition-colors group-hover:text-accent"
                />
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
