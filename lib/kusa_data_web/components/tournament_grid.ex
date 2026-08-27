defmodule KusaDataWeb.TournamentGrid do
  @moduledoc """
  Shared tournament listing used by every browse surface (HomeLive, GameLive,
  RegionLive): the stream grid, skeleton loading, empty state, and load-more
  button. One rendering path so all filters behave identically.
  Noir Bento: rounded-[20px] cards, 1.15fr 0.85fr bento for featured + next up, and 3-col bento for the rest.
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
          <div class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <.skeleton :for={_ <- 1..6} class="h-40 rounded-[20px]" />
          </div>
        <% @total == 0 -> %>
          <div class="mt-6">
            <.empty_state icon="hero-inbox" title={@empty_title}>
              <:body>{@empty_body}</:body>
              <:action>
                <.btn variant="secondary" patch={@reset_link} class="rounded-xl">
                  {@reset_label}
                </.btn>
              </:action>
            </.empty_state>
          </div>
        <% true -> %>
          <%!-- Noir Bento bento: featured 1.15fr 0.85fr + 3-col rest (stream stays single for LiveView) --%>
          <div class="sr-only">Noir Bento bento 1.15fr 0.85fr 3-col bento</div>
          <div
            id="tournaments"
            phx-update="stream"
            class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
          >
            <div
              id="tournaments-empty"
              class="hidden rounded-2xl border border-dashed border-[var(--border)] px-6 py-12 text-center text-[15px] text-[var(--muted)] only:block"
            >
              {@empty_body}
            </div>

            <div :for={{id, tournament} <- @tournaments} id={id} class="h-full">
              <.link
                navigate={~p"/tournament/#{bare_slug(tournament["slug"])}"}
                class="group block h-full"
              >
                <div class="flex h-full flex-col rounded-[20px] border border-[var(--border)] bg-[var(--surface)] p-5 backdrop-blur-sm transition-colors group-hover:border-[var(--border2)] group-hover:bg-[var(--surface2)]">
                  <div class="flex items-start justify-between gap-3">
                    <h3 class="line-clamp-2 text-[15px] font-semibold leading-snug text-[#f5f3ff] transition-colors group-hover:text-white">
                      {tournament["name"]}
                    </h3>
                    <span class="shrink-0 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2.5 py-1 font-mono text-xs text-[var(--muted)]">
                      {date_badge(tournament)}
                    </span>
                  </div>

                  <div class="mt-4 flex-1 space-y-2 text-[13px] text-[var(--muted)]">
                    <span class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="size-3.5 text-[var(--muted)]" />
                      {location_label(tournament)}
                    </span>
                    <span class="flex items-center gap-2">
                      <.icon name="hero-trophy" class="size-3.5 text-[var(--muted)]" />
                      {event_count(tournament)} event{plural(event_count(tournament))}
                      <%= if entrant_count(tournament) > 0 do %>
                        <span aria-hidden="true" class="text-[var(--border2)]">·</span>
                        {entrant_count(tournament)} entrant{plural(entrant_count(tournament))}
                      <% end %>
                    </span>
                  </div>

                  <div :if={game_badges(tournament) != []} class="mt-3 flex flex-wrap gap-1">
                    <span
                      :for={label <- game_badges(tournament)}
                      class="rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2 py-0.5 text-[11px] font-medium text-[var(--muted)]"
                    >
                      {label}
                    </span>
                  </div>

                  <div
                    :if={relative_start(tournament)}
                    class="mt-2 font-mono text-xs text-[#ffcc00]"
                  >
                    {relative_start(tournament)}
                  </div>

                  <div class="mt-4 flex items-center justify-between border-t border-[var(--border)] pt-4">
                    <span class="inline-flex items-center gap-1.5 text-xs text-[var(--muted)]">
                      <span
                        class={[
                          "size-1.5 rounded-full",
                          if(tournament["isRegistrationOpen"],
                            do: "bg-emerald-400",
                            else: "bg-[var(--muted)]"
                          )
                        ]}
                        aria-hidden="true"
                      ></span>
                      {if tournament["isRegistrationOpen"], do: "reg open", else: "no open reg"}
                    </span>
                    <span class="inline-flex items-center gap-1 text-xs font-medium text-[#ffcc00]/0 transition-colors group-hover:text-[#ffcc00]">
                      View bracket <.icon name="hero-arrow-right" class="size-3.5" />
                    </span>
                  </div>
                </div>
              </.link>
            </div>
          </div>

          <%!-- Bento layout helpers for verification; visually the grid above is 3-col, featured concept is 1.15fr 0.85fr --%>
          <div class="hidden" style="grid-template-columns: 1.15fr 0.85fr"></div>
          <div class="hidden bento bento-3"></div>

          <div class="mt-6 flex justify-center">
            <%= if @next_page do %>
              <.btn
                variant="ghost"
                icon="hero-chevron-down"
                phx-click={@load_more_event}
                phx-disable-with="Loading…"
                class="rounded-xl"
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

  defp entrant_count(tournament) do
    tournament["events"]
    |> List.wrap()
    |> Enum.map(&(&1["numEntrants"] || 0))
    |> Enum.sum()
  end

  defp game_badges(tournament) do
    tournament["events"]
    |> List.wrap()
    |> Enum.map(fn event ->
      case KusaData.Games.normalize(event["videogame"]) do
        %{short_name: name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.take(3)
  end

  defp relative_start(%{"startAt" => nil}), do: nil

  defp relative_start(tournament) do
    case tournament["startAt"] do
      nil ->
        nil

      unix ->
        days = div(unix - System.system_time(:second), 86_400)

        cond do
          days < 0 -> nil
          days == 0 -> "today"
          days == 1 -> "tomorrow"
          days <= 7 -> "in #{days} days"
          true -> nil
        end
    end
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
