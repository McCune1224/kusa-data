defmodule KusaDataWeb.TournamentGrid do
  @moduledoc """
  Shared tournament listing used by every browse surface (HomeLive, GameLive,
  RegionLive): the stream grid, skeleton loading, empty state, and load-more
  button. One rendering path so all filters behave identically.
  """

  use KusaDataWeb, :html

  attr :tournaments, :map, required: true, doc: "the `@streams.tournaments` collection"
  attr :total, :integer, default: 0
  attr :loading, :boolean, default: false
  attr :error, :any, default: nil, doc: "last load error, used for the empty-state hint"
  attr :empty_title, :string, default: "No tournaments found"
  attr :empty_body, :string, default: ""
  attr :reset_link, :string, default: "/"
  attr :reset_label, :string, default: "Browse all upcoming"
  attr :next_page, :integer, default: nil
  attr :load_more_event, :string, default: "load-more"

  def tournament_grid(assigns) do
    ~H"""
    <div>
      <%= cond do %>
        <% @loading && @total == 0 -> %>
          <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <.skeleton :for={_ <- 1..6} class="h-40 rounded-none" />
          </div>
        <% @total == 0 -> %>
          <div class="mt-6">
            <.empty_state icon="hero-inbox" title={@empty_title}>
              <:body>{@empty_body}</:body>
              <:action>
                <.btn variant="secondary" patch={@reset_link} class="rounded-none">
                  {@reset_label}
                </.btn>
              </:action>
            </.empty_state>
          </div>
        <% true -> %>
          <div
            id="tournaments"
            phx-update="stream"
            class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
          >
            <div
              id="tournaments-empty"
              class="hidden border border-dashed border-stone-800 px-6 py-12 text-center text-[15px] text-stone-400 only:block"
            >
              {@empty_body}
            </div>

            <div :for={{id, tournament} <- @tournaments} id={id} class="h-full">
              <.link
                navigate={~p"/tournament/#{bare_slug(tournament["slug"])}"}
                class="group block h-full"
              >
                <div class="rule-hover flex h-full flex-col border border-stone-800 bg-stone-900/40 p-5 transition-colors group-hover:border-stone-600 group-hover:bg-stone-900/70">
                  <div class="flex items-start justify-between gap-3">
                    <h3 class="line-clamp-2 text-lg font-medium leading-snug text-stone-200 transition-colors group-hover:text-stone-50">
                      {tournament["name"]}
                    </h3>
                    <span class="shrink-0 border border-stone-700/70 px-2.5 py-1 font-mono text-xs text-stone-400">
                      {date_badge(tournament)}
                    </span>
                  </div>

                  <div class="mt-5 flex-1 space-y-2 text-[15px] text-stone-400">
                    <span class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="size-3.5 text-stone-600" />
                      {location_label(tournament)}
                    </span>
                    <span class="flex items-center gap-2">
                      <.icon name="hero-trophy" class="size-3.5 text-stone-600" />
                      {event_count(tournament)} event{plural(event_count(tournament))}
                    </span>
                  </div>

                  <div class="mt-5 flex items-center justify-between border-t border-stone-800/70 pt-4">
                    <span class="inline-flex items-center gap-1.5 text-xs text-stone-500">
                      <span
                        class={[
                          "size-1.5 rounded-full",
                          if(tournament["isRegistrationOpen"],
                            do: "bg-emerald-400",
                            else: "bg-stone-700"
                          )
                        ]}
                        aria-hidden="true"
                      ></span>
                      {if tournament["isRegistrationOpen"], do: "reg open", else: "no open reg"}
                    </span>
                    <span class="inline-flex items-center gap-1 text-xs font-medium text-lime-400/0 transition-colors group-hover:text-lime-300">
                      View bracket <.icon name="hero-arrow-right" class="size-3.5" />
                    </span>
                  </div>
                </div>
              </.link>
            </div>
          </div>

          <div class="mt-10 flex justify-center">
            <%= if @next_page do %>
              <.btn
                variant="ghost"
                icon="hero-chevron-down"
                phx-click={@load_more_event}
                phx-disable-with="Loading…"
                class="rounded-none"
              >
                Load more
              </.btn>
            <% end %>
          </div>
      <% end %>
    </div>
    """
  end

  defp date_badge(tournament) do
    timezone = tournament["timezone"] || "UTC"

    case tournament["startAt"] do
      nil -> "TBA"
      unix -> short_date(unix, timezone)
    end
  end

  defp location_label(tournament) do
    city = tournament["city"]
    state = tournament["addrState"]
    country = tournament["countryCode"]

    cond do
      city && state -> "#{city}, #{state}"
      city -> city
      state -> state
      country -> country
      true -> "online"
    end
  end

  defp event_count(tournament), do: length(tournament["events"] || [])

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
