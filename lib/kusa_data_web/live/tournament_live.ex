defmodule KusaDataWeb.TournamentLive do
  @moduledoc """
  Tournament detail page: header card plus a grid of the tournament's events.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, tournament: nil, slug: nil)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    tournament = safe_tournament(slug)
    {:noreply, assign(socket, slug: slug, tournament: tournament)}
  end

  defp safe_tournament(slug) do
    case KusaData.Tournaments.by_slug(slug) do
      {:ok, tournament, _cache} -> tournament
      {:error, _reason} -> nil
    end
  end

  @impl true
  def render(assigns) do
    tournament = assigns.tournament
    bare_slug = if(tournament, do: Format.bare_slug(tournament["slug"]), else: nil)

    events =
      if tournament do
        Enum.map(tournament["events"] || [], fn event ->
          {label, variant} = event_state(event["state"])
          Map.merge(event, %{"state_label" => label, "state_variant" => variant})
        end)
      else
        []
      end

    assigns =
      assigns
      |> assign(:events, events)
      |> assign(:root_id, if(bare_slug, do: "tournament-#{bare_slug}", else: nil))
      |> assign(:name, if(tournament, do: tournament["name"]))
      |> assign(:start_date, if(tournament, do: Format.date(tournament["startAt"])))
      |> assign(:end_date, if(tournament, do: Format.date(tournament["endAt"])))
      |> assign(:city, if(tournament, do: tournament["city"]))
      |> assign(:state, if(tournament, do: tournament["addrState"]))
      |> assign(:country, if(tournament, do: tournament["countryCode"]))
      |> assign(:venue, if(tournament, do: tournament["venueName"]))
      |> assign(:attendees, if(tournament, do: tournament["numAttendees"]))
      |> assign(:open, if(tournament, do: tournament["isRegistrationOpen"]))

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id={@root_id} class="space-y-8">
        <%= if is_nil(@tournament) do %>
          <.empty
            class="mt-6"
            icon="hero-magnifying-glass"
            title="Tournament not found"
            description="We couldn’t find that tournament. It may have been removed or the link is incorrect."
          />
        <% else %>
          <section class="rounded-none border border-line bg-surface px-6 py-8 sm:px-10 sm:py-10">
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div class="min-w-0">
                <h1 class="font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
                  {@name}
                </h1>
                <p class="mt-2 text-sm text-muted">
                  <span class="text-ink">{@start_date}</span>
                  <%= if @end_date && @end_date != @start_date do %>
                    <span class="text-faint"> – </span>{@end_date}
                  <% end %>
                </p>
                <p class="mt-1 text-sm text-muted">
                  <%= if @city do %>
                    <span class="text-ink">{@city}</span>
                  <% end %>
                  <%= if @state do %>
                    , {@state}
                  <% end %>
                  <%= if @country do %>
                    <span class="text-faint">{@country}</span>
                  <% end %>
                  <%= if @venue do %>
                    <span class="text-faint"> · </span>{@venue}
                  <% end %>
                </p>
              </div>
              <div class="flex flex-col items-end gap-3">
                <%= if @attendees do %>
                  <.stat label="Entrants" value={to_string(@attendees)} />
                <% end %>
                <%= if @open do %>
                  <.badge variant={:accent}>Registration open</.badge>
                <% end %>
              </div>
            </div>
          </section>

          <section>
            <h2 class="font-display text-xl font-semibold text-ink">Events</h2>
            <%= if Enum.empty?(@events) do %>
              <.empty
                class="mt-6"
                icon="hero-trophy"
                title="No events listed"
              />
            <% else %>
              <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <%= for event <- @events do %>
                  <.link
                    id={"event-#{event["id"]}"}
                    navigate={~p"/event/#{event["id"]}"}
                    class={[
                      "group flex flex-col gap-3 rounded-none border border-line bg-surface p-5",
                      "transition-all duration-150 hover:border-accent-line hover:bg-surface-2"
                    ]}
                  >
                    <div class="flex items-start justify-between gap-3">
                      <h3 class="font-display text-lg font-semibold leading-tight text-ink transition-colors group-hover:text-accent">
                        {event["name"]}
                      </h3>
                      <.badge variant={event["state_variant"]}>{event["state_label"]}</.badge>
                    </div>
                    <p class="text-sm text-muted">
                      {event["videogame"]["name"]}
                    </p>
                    <div class="mt-auto flex items-center gap-3 text-xs text-faint">
                      <span class="inline-flex items-center gap-1">
                        <span class="hero-users size-3.5"></span>
                        {event["numEntrants"]} entrants
                      </span>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp event_state(3), do: {"Completed", :muted}
  defp event_state(1), do: {"Live", :accent}
  defp event_state(_), do: {"Upcoming", :outline}
end
