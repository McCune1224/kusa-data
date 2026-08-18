defmodule KusaDataWeb.LeagueLive do
  use KusaDataWeb, :live_view

  alias KusaData.Leagues

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :leagues,
       league: nil,
       members: [],
       tournaments: [],
       seasons: [],
       standings: nil,
       error: nil,
       loading: true,
       import_form: to_form(%{"slug" => ""}),
       member_form: to_form(%{"player_id" => "", "canonical_tag" => ""}),
       season_form: to_form(%{"name" => "", "start_at" => "", "end_at" => ""})
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    socket =
      socket
      |> assign(league: nil, loading: true, error: nil, league_id: id)
      |> spawn_load(id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:league_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, data} ->
        {:noreply,
         assign(socket,
           league: data.league,
           members: data.members,
           tournaments: data.tournaments,
           seasons: data.seasons,
           standings: data.standings,
           loading: false,
           error: nil,
           load_ref: nil
         )}

      {:error, reason} ->
        {:noreply, assign(socket, league: nil, loading: false, error: reason, load_ref: nil)}
    end
  end

  def handle_info({:league_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket, id) do
    ref = make_ref()
    parent = self()
    user = socket.assigns.current_user

    Task.start(fn ->
      send(parent, {:league_loaded, ref, load_league(user, id)})
    end)

    assign(socket, load_ref: ref)
  end

  defp load_league(user, id) do
    case Leagues.get_owned_league(user, id) do
      nil ->
        {:error, :not_found}

      league ->
        members = Leagues.members(league)
        tournaments = Leagues.tournaments(league)
        seasons = Leagues.seasons(league)

        standings =
          case seasons do
            [season | _] ->
              case Leagues.season_standings(league, season) do
                {:ok, rows} -> {:ok, rows}
                _ -> :unavailable
              end

            [] ->
              nil
          end

        {:ok,
         %{
           league: league,
           members: members,
           tournaments: tournaments,
           seasons: seasons,
           standings: standings
         }}
    end
  end

  @impl true
  def handle_event("import", %{"slug" => slug}, socket) do
    slug = String.trim(slug)

    case Leagues.import_tournament_with_links(socket.assigns.league, slug) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Imported #{slug}: #{result["added"]} members linked, #{length(result["unresolved"])} unresolved tags to review."
         )
         |> push_patch(to: "/leagues/#{socket.assigns.league.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("add-member", %{"player_id" => player_id, "canonical_tag" => tag}, socket) do
    case Leagues.add_member(socket.assigns.league, parse_int(player_id), blank(tag)) do
      {:ok, _member} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member added.")
         |> push_patch(to: "/leagues/#{socket.assigns.league.id}")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not add member: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("remove-member", %{"id" => id}, socket) do
    Leagues.remove_member(socket.assigns.league, parse_int(id))

    {:noreply,
     socket
     |> put_flash(:info, "Member removed.")
     |> push_patch(to: "/leagues/#{socket.assigns.league.id}")}
  end

  @impl true
  def handle_event(
        "create-season",
        %{"name" => name, "start_at" => start_at, "end_at" => end_at},
        socket
      ) do
    attrs = %{
      name: name,
      start_at: parse_datetime(start_at),
      end_at: parse_datetime(end_at)
    }

    case Leagues.create_season(socket.assigns.league, attrs) do
      {:ok, _season} ->
        {:noreply,
         socket
         |> put_flash(:info, "Season created.")
         |> push_patch(to: "/leagues/#{socket.assigns.league.id}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Season invalid: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete-league", _params, socket) do
    Leagues.delete_league(socket.assigns.league)
    {:noreply, socket |> put_flash(:info, "League deleted.") |> push_navigate(to: "/leagues")}
  end

  defp parse_int(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_datetime(""), do: nil

  defp parse_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp blank(nil), do: nil

  defp blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      v -> v
    end
  end

  defp blank(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <%= if @loading do %>
          <div class="space-y-4">
            <.skeleton class="h-3 w-24" />
            <.skeleton class="mt-4 h-9 w-64" />
            <div class="mt-8 grid gap-4 lg:grid-cols-2">
              <.skeleton :for={_ <- 1..2} class="h-48 rounded-xl" />
            </div>
          </div>
        <% else %>
          <%= if @league == nil do %>
            <.empty_state icon="hero-exclamation-triangle" title="League not found">
              <:body>You may not own this league, or it was deleted.</:body>
              <:action>
                <.btn variant="primary" navigate={~p"/leagues"}>Your leagues</.btn>
              </:action>
            </.empty_state>
          <% else %>
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div>
                <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/leagues"}>
                  Leagues
                </.btn>
                <h1 class="mt-3 text-3xl font-semibold tracking-tight text-stone-50">
                  {@league.name}
                </h1>
                <p class="mt-1 text-sm text-stone-400">
                  {length(@members)} members · {length(@tournaments)} tournaments · {length(@seasons)} seasons
                </p>
              </div>
              <button
                type="button"
                phx-click="delete-league"
                class="rounded-none border border-rose-500/40 px-3 py-1.5 text-xs font-semibold text-rose-300 transition-colors hover:bg-rose-500/10"
              >
                Delete league
              </button>
            </div>

            <div class="mt-8 grid gap-6 lg:grid-cols-2">
              <div class="space-y-6">
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Import a tournament
                  </h2>
                  <p class="mt-2 text-sm text-stone-500">
                    One-click import links known player ids; unresolved tags are listed for review.
                  </p>
                  <.form
                    for={@import_form}
                    id="import-form"
                    phx-submit="import"
                    class="mt-3 flex gap-2"
                  >
                    <.input
                      field={@import_form[:slug]}
                      type="text"
                      placeholder="tournament/slug"
                      class="h-10 flex-1 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                    <.btn variant="primary" type="submit" class="rounded-none">Import</.btn>
                  </.form>
                </.card>

                <.card class="p-5">
                  <div class="flex items-center justify-between gap-3">
                    <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                      Members
                    </h2>
                    <span class="font-mono text-[13px] text-stone-500">{length(@members)}</span>
                  </div>
                  <div class="mt-4 space-y-1">
                    <div
                      :for={member <- @members}
                      class="flex items-center justify-between gap-3 rounded-md px-3 py-2.5 hover:bg-stone-900/60"
                    >
                      <span class="truncate text-[15px] text-stone-300">
                        {member.canonical_tag || "player #{member.player_id}"}
                      </span>
                      <button
                        type="button"
                        phx-click="remove-member"
                        phx-value-id={member.id}
                        class="shrink-0 text-stone-500 transition-colors hover:text-rose-400"
                        aria-label="Remove member"
                      >
                        <.icon name="hero-x-mark" class="size-4" />
                      </button>
                    </div>
                    <div :if={@members == []} class="text-sm text-stone-600">No members yet.</div>
                  </div>
                  <.form
                    for={@member_form}
                    id="member-form"
                    phx-submit="add-member"
                    class="mt-4 flex gap-2"
                  >
                    <.input
                      field={@member_form[:player_id]}
                      type="text"
                      placeholder="player id"
                      class="h-10 w-28 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                    <.input
                      field={@member_form[:canonical_tag]}
                      type="text"
                      placeholder="canonical tag"
                      class="h-10 flex-1 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                    <.btn variant="secondary" type="submit" class="rounded-none">Add</.btn>
                  </.form>
                </.card>
              </div>

              <div class="space-y-6">
                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    New season
                  </h2>
                  <.form
                    for={@season_form}
                    id="season-form"
                    phx-submit="create-season"
                    class="mt-3 space-y-3"
                  >
                    <.input
                      field={@season_form[:name]}
                      type="text"
                      placeholder="2026 Season 1"
                      class="h-10 w-full rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                    <div class="flex gap-2">
                      <.input
                        field={@season_form[:start_at]}
                        type="datetime-local"
                        class="h-10 flex-1 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                      />
                      <.input
                        field={@season_form[:end_at]}
                        type="datetime-local"
                        class="h-10 flex-1 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                      />
                    </div>
                    <.btn variant="secondary" type="submit" class="rounded-none w-full">
                      Create season
                    </.btn>
                  </.form>

                  <div class="mt-5 border-t border-stone-800/70 pt-4">
                    <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-stone-500">
                      Seasons
                    </h3>
                    <div :for={season <- @seasons} class="mt-2 text-sm text-stone-400">
                      {season.name} · {format_date(season.start_at)} → {format_date(season.end_at)}
                    </div>
                  </div>
                </.card>

                <.card class="p-5">
                  <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                    Season standings
                  </h2>
                  <%= if @standings == nil do %>
                    <p class="mt-3 text-sm text-stone-500">Create a season to compute standings.</p>
                  <% else %>
                    <%= if @standings == :unavailable do %>
                      <p class="mt-3 text-sm text-stone-500">
                        Standings unavailable (rankings data not reachable).
                      </p>
                    <% else %>
                      <div class="mt-4 space-y-1">
                        <div
                          :for={{rank, player} <- Enum.with_index(@standings, 1)}
                          class="flex items-center justify-between gap-3 rounded-md px-3 py-2.5 hover:bg-stone-900/60"
                        >
                          <span class="w-8 shrink-0 font-mono text-sm font-bold text-stone-500">
                            {rank}
                          </span>
                          <.link
                            navigate={~p"/player/#{player["player_id"]}"}
                            class="min-w-0 flex-1 truncate text-[15px] text-stone-200 hover:text-lime-300"
                          >
                            {player["gamer_tag"]}
                          </.link>
                          <span class="shrink-0 font-mono text-sm font-semibold text-stone-100">
                            {player["rating"]}
                          </span>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </.card>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(_), do: "—"
end
