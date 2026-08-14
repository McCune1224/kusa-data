defmodule KusaDataWeb.PlayerLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Players, Repo, SetDetails, Stats}

  @detail_per_page 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:game, Repo.get_by(Game, key: "melee"))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Players.get(id) do
      nil ->
        {:noreply,
         socket
         |> assign(:not_found, true)
         |> assign(:player, nil)
         |> assign(:page_title, "Player not found")}

      player ->
        game = socket.assigns.game
        rating = if game, do: Players.rating(game, player), else: nil
        sets = Players.sets(player, 50)
        win_loss = Stats.win_loss(sets, player.id)
        streak = Stats.current_streak(sets, player.id)
        best = Stats.best_streak(sets, player.id)

        socket =
          socket
          |> assign(:not_found, false)
          |> assign(:player, player)
          |> assign(:rating, rating)
          |> assign(:sets, sets)
          |> assign(:win_loss, win_loss)
          |> assign(:streak, streak)
          |> assign(:best, best)
          |> assign(:detail_state, :loading)
          |> assign(:characters, %{})
          |> assign(:stages, %{})
          |> assign(:page_title, player.gamer_tag)

        send(self(), :load_details)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:load_details, socket) do
    player = socket.assigns.player

    {state, characters, stages} =
      if player.player_id do
        case SetDetails.API.for_player(player.player_id, 1, @detail_per_page) do
          {:ok, payload} ->
            details = SetDetails.Parse.parse(payload, player.user_id)
            {:loaded, details.characters, details.stages}

          {:error, _reason} ->
            {:error, %{}, %{}}
        end
      else
        {:empty, %{}, %{}}
      end

    {:noreply,
     socket
     |> assign(:detail_state, state)
     |> assign(:characters, characters)
     |> assign(:stages, stages)}
  end

  defp format_win_rate(win_loss) do
    case win_loss.win_rate do
      nil -> "—"
      rate -> "#{Float.round(rate * 100, 1)}%"
    end
  end

  defp result_badge(set, player_id) do
    if set.winner_player_id == player_id do
      {:success, "W"}
    else
      {:neutral, "L"}
    end
  end

  defp score_for(set, player_id) do
    if set.winner_player_id == player_id do
      "#{set.winner_score}-#{set.loser_score}"
    else
      "#{set.loser_score}-#{set.winner_score}"
    end
  end

  defp opponent(set, player_id) do
    if set.winner_player_id == player_id, do: set.loser, else: set.winner
  end

  defp format_date(nil), do: "—"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="player-page" class="flex flex-col gap-8">
      <%= if @not_found do %>
        <.empty_state
          title="Player not found"
          hint="This player isn't in the index. Search from the home page to find them."
        />
      <% else %>
        <header class="flex flex-wrap items-baseline justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold tracking-tight text-ink">
              {if @player.prefix, do: "#{@player.prefix} | "}{@player.gamer_tag}
            </h1>
            <p class="mt-1 text-ink-muted">
              Melee · start.gg user #{@player.user_id} · player #{@player.player_id || "—"}
            </p>
          </div>
          <div class="flex gap-2">
            <.button navigate={~p"/vs"} variant="outline" size="sm">VS Mode</.button>
            <.button navigate={~p"/rankings"} variant="ghost" size="sm">Rankings</.button>
          </div>
        </header>

        <.stat_grid>
          <.stat
            label="Elo"
            value={trunc((@rating && @rating.elo) || 0)}
            hint={@rating && "#{@rating.sets} rated sets"}
          />
          <.stat
            label="W/L"
            value={"#{@win_loss.wins}-#{@win_loss.losses}"}
            hint={format_win_rate(@win_loss)}
          />
          <.stat label="Current streak" value={streak_value(@streak)} />
          <.stat label="Best win streak" value={@best.win} />
        </.stat_grid>

        <section class="flex flex-col gap-3">
          <h2 class="text-xl font-semibold text-ink">Set history</h2>

          <%= if @sets == [] do %>
            <.empty_state
              title="No sets on record"
              hint="Completed sets appear here once a crawl window covers this player."
            />
          <% else %>
            <.table id="set-history">
              <:head>
                <th class="p-3 text-left">Date</th>
                <th class="p-3 text-left">Event</th>
                <th class="p-3 text-left">Opponent</th>
                <th class="p-3 text-right">Result</th>
                <th class="p-3 text-right">Score</th>
              </:head>

              <tr :for={set <- @sets}>
                <td class="p-3 whitespace-nowrap text-ink-muted">{format_date(set.completed_at)}</td>
                <td class="p-3 text-ink-muted">{set.event.name}</td>
                <td class="p-3">
                  <%= if opponent = opponent(set, @player.id) do %>
                    <.link
                      href={~p"/players/#{opponent.id}"}
                      class="font-medium text-ink hover:text-accent"
                    >
                      {opponent.gamer_tag}
                    </.link>
                  <% else %>
                    <span class="text-ink-faint">Bye</span>
                  <% end %>
                </td>
                <td class="p-3 text-right">
                  <% {tone, label} = result_badge(set, @player.id) %>
                  <.badge tone={tone}>{label}</.badge>
                </td>
                <td class="p-3 text-right font-mono">{score_for(set, @player.id)}</td>
              </tr>
            </.table>
          <% end %>
        </section>

        <section class="flex flex-col gap-3">
          <h2 class="text-xl font-semibold text-ink">Characters & stages</h2>
          <p class="text-sm text-ink-muted">
            Game-level detail is pulled from start.gg on demand — sets without bracket reports show nothing here.
          </p>

          <%= case @detail_state do %>
            <% :loading -> %>
              <.loading label="Fetching set details from start.gg…" />
            <% :error -> %>
              <.empty_state
                title="Couldn't load set details"
                hint="start.gg may be rate-limiting. Refresh to try again."
              />
            <% :empty -> %>
              <.empty_state
                title="No game-level detail for this player"
                hint="The sets we hold don't report characters or stages yet."
              />
            <% :loaded -> %>
              <%= if @characters == %{} and @stages == %{} do %>
                <.empty_state
                  title="No game-level detail reported"
                  hint="Bracket reporters haven't logged characters or stages for these sets."
                />
              <% else %>
                <div class="grid gap-3 lg:grid-cols-2">
                  <%= if @characters != %{} do %>
                    <.card>
                      <h3 class="mb-3 font-semibold text-ink">Character usage</h3>
                      <.table id="character-stats">
                        <:head>
                          <th class="p-3 text-left">Character</th>
                          <th class="p-3 text-right">Games</th>
                          <th class="p-3 text-right">Wins</th>
                          <th class="p-3 text-right">Win rate</th>
                        </:head>
                        <tr :for={{name, %{games: games, wins: wins}} <- sort_counts(@characters)}>
                          <td class="p-3 font-medium text-ink">{name}</td>
                          <td class="p-3 text-right font-mono">{games}</td>
                          <td class="p-3 text-right font-mono">{wins}</td>
                          <td class="p-3 text-right font-mono">{rate(wins, games)}</td>
                        </tr>
                      </.table>
                    </.card>
                  <% end %>

                  <%= if @stages != %{} do %>
                    <.card>
                      <h3 class="mb-3 font-semibold text-ink">Stage record</h3>
                      <.table id="stage-stats">
                        <:head>
                          <th class="p-3 text-left">Stage</th>
                          <th class="p-3 text-right">Games</th>
                          <th class="p-3 text-right">Wins</th>
                          <th class="p-3 text-right">Win rate</th>
                        </:head>
                        <tr :for={{name, %{games: games, wins: wins}} <- sort_counts(@stages)}>
                          <td class="p-3 font-medium text-ink">{name}</td>
                          <td class="p-3 text-right font-mono">{games}</td>
                          <td class="p-3 text-right font-mono">{wins}</td>
                          <td class="p-3 text-right font-mono">{rate(wins, games)}</td>
                        </tr>
                      </.table>
                    </.card>
                  <% end %>
                </div>
              <% end %>
          <% end %>
        </section>
      <% end %>
    </div>
    """
  end

  defp streak_value(%{type: nil}), do: "—"

  defp streak_value(%{type: :win, count: count}), do: "W#{count}"
  defp streak_value(%{type: :loss, count: count}), do: "L#{count}"

  defp sort_counts(counts) do
    Enum.sort_by(counts, fn {_name, %{games: games}} -> -games end)
  end

  defp rate(wins, games) do
    "#{Float.round(wins / games * 100, 1)}%"
  end
end
