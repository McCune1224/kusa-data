defmodule KusaDataWeb.Components do
  @moduledoc """
  Shared presentational cards used across LiveViews (tournament, player, event).
  Leaf module: imports CoreComponents + Format + VerifiedRoutes only, so it can
  be safely imported by the web module's `html_helpers` without a cycle.
  """
  use Phoenix.Component
  import KusaDataWeb.CoreComponents
  alias KusaDataWeb.Format

  use Phoenix.VerifiedRoutes,
    endpoint: KusaDataWeb.Endpoint,
    router: KusaDataWeb.Router,
    statics: KusaDataWeb.static_paths()

  @doc """
  A tournament directory card. Accepts a start.gg tournament node.
  """
  attr :tournament, :map, required: true
  attr :class, :string, default: ""

  def tournament_card(assigns) do
    t = assigns.tournament

    assigns =
      assign(assigns,
        slug: Format.bare_slug(t["slug"]),
        name: t["name"],
        start_at: t["startAt"],
        city: t["city"],
        state: t["addrState"],
        country: t["countryCode"],
        attendees: t["numAttendees"] || 0,
        event_count: length(t["events"] || []),
        open: t["isRegistrationOpen"]
      )

    ~H"""
    <.link
      id={"tournament-#{@slug}"}
      navigate={~p"/tournament/#{@slug}"}
      class={[
        "group flex flex-col gap-3 rounded-card border border-line bg-surface p-5",
        "transition-all duration-150 hover:border-accent-line hover:bg-surface-2",
        @class
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <h3 class="font-display text-lg font-semibold leading-tight text-ink transition-colors group-hover:text-accent">
          {@name}
        </h3>
        <%= if @open do %>
          <.badge variant={:accent}>Registration open</.badge>
        <% end %>
      </div>

      <p class="text-sm text-muted">
        <%= if @start_at do %>
          <span class="text-ink">{Format.date(@start_at)}</span>
        <% end %>
        <%= if @city do %>
          <span class="text-faint"> · </span>{@city}
        <% end %>
        <%= if @state do %>
          , {@state}
        <% end %>
        <%= if @country do %>
          <span class="text-faint">{@country}</span>
        <% end %>
      </p>

      <div class="mt-auto flex items-center gap-3 text-xs text-faint">
        <span class="inline-flex items-center gap-1">
          <span class="hero-users size-3.5"></span>
          {@attendees} entrants
        </span>
        <%= if @event_count > 0 do %>
          <span class="text-line-2">·</span>
          <span>{@event_count} event{if @event_count != 1, do: "s"}</span>
        <% end %>
      </div>
    </.link>
    """
  end
end
