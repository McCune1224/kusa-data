defmodule KusaDataWeb.CompareLive do
  @moduledoc """
  Side-by-side comparison of two players: overall record, head-to-head, and
  recent form / trend. Backed by `KusaData.Players.compare/3`.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"a" => "", "b" => ""}),
       result: nil
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("compare", %{"a" => a, "b" => b}, socket) do
    result =
      case {parse_id(a), parse_id(b)} do
        {{:ok, id_a}, {:ok, id_b}} -> run_compare(id_a, id_b)
        _ -> {:error, :invalid_ids}
      end

    {:noreply, assign(socket, form: to_form(%{"a" => a, "b" => b}), result: result)}
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}

  defp run_compare(id_a, id_b) do
    case Players.compare(id_a, id_b, %{}) do
      {:ok, data, _cache} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def render(assigns) do
    {player_a, player_b, head_to_head, events_overlap} =
      case assigns.result do
        {:ok, data} ->
          [a, b] = data["players"]
          comparison = data["comparison"] || %{}
          {a, b, data["head_to_head"], comparison["events_overlap"]}

        _ ->
          {nil, nil, nil, nil}
      end

    assigns =
      assign(assigns,
        player_a: player_a,
        player_b: player_b,
        head_to_head: head_to_head,
        events_overlap: events_overlap
      )

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:players}>
      <div id="compare-live" class="mx-auto flex max-w-5xl flex-col gap-8">
        <header class="flex flex-col gap-2">
          <h1 class="font-display text-3xl font-bold tracking-tight text-ink">Compare players</h1>
          <p class="max-w-2xl text-sm text-muted">
            Enter two start.gg player IDs to see a side-by-side breakdown of their records,
            head-to-head, and recent form.
          </p>
        </header>

        <.card class="p-5">
          <.form
            for={@form}
            id="compare-form"
            phx-submit="compare"
            class="grid grid-cols-1 gap-4 sm:grid-cols-[1fr_1fr_auto] sm:items-end"
          >
            <.input field={@form[:a]} id="player-a-input" label="Player A ID" placeholder="e.g. 100" />
            <.input field={@form[:b]} id="player-b-input" label="Player B ID" placeholder="e.g. 200" />
            <div class="pb-1">
              <.button type="submit">Compare</.button>
            </div>
          </.form>
        </.card>

        <%= if match?({:error, _}, @result) do %>
          <div id="compare-error">
            <.empty
              class="mt-2"
              icon="hero-exclamation-triangle"
              title="Couldn't compare players"
              description="Enter two valid numeric player IDs to see a comparison."
            />
          </div>
        <% end %>

        <%= if match?({:ok, _}, @result) do %>
          <div id="compare-results" class="flex flex-col gap-8">
            <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
              <%= for {player, tag} <- [{@player_a, "Player A"}, {@player_b, "Player B"}] do %>
                <.card class="p-5">
                  <div class="flex items-center justify-between gap-2">
                    <h2 class="truncate font-display text-lg font-semibold text-ink">
                      {player["gamer_tag"] || tag}
                    </h2>
                    <.badge variant={:accent}>{tag}</.badge>
                  </div>

                  <div class="mt-4 grid grid-cols-2 gap-3">
                    <.stat label="Wins" value={to_string(player["wins"])} />
                    <.stat label="Losses" value={to_string(player["losses"])} />
                    <.stat label="Win rate" value={Format.percent(player["win_rate"])} />
                    <.stat label="Sets seen" value={to_string(player["sets_seen"])} />
                    <.stat label="Events entered" value={to_string(player["events_entered"])} />
                  </div>

                  <%= if Enum.any?(player["finishes"] || []) do %>
                    <h3 class="mt-6 text-xs font-semibold uppercase tracking-[0.08em] text-muted">
                      Best placements
                    </h3>
                    <.table class="mt-2">
                      <thead>
                        <tr class="text-left text-xs uppercase tracking-[0.08em] text-faint">
                          <th class="px-3 py-2 font-medium">Event</th>
                          <th class="px-3 py-2 font-medium">Placement</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for finish <- player["finishes"] do %>
                          <tr class="border-t border-line">
                            <td class="px-3 py-2 text-ink">{to_string(finish["event_id"])}</td>
                            <td class="px-3 py-2 text-muted">{to_string(finish["placement"])}</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </.table>
                  <% end %>

                  <%= if Enum.any?(player["time_buckets"] || []) do %>
                    <h3 class="mt-6 text-xs font-semibold uppercase tracking-[0.08em] text-muted">
                      Monthly trend
                    </h3>
                    <.table class="mt-2">
                      <thead>
                        <tr class="text-left text-xs uppercase tracking-[0.08em] text-faint">
                          <th class="px-3 py-2 font-medium">Month</th>
                          <th class="px-3 py-2 font-medium">Sets</th>
                          <th class="px-3 py-2 font-medium">Win rate</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for bucket <- player["time_buckets"] do %>
                          <tr class="border-t border-line">
                            <td class="px-3 py-2 text-ink">{bucket["month"]}</td>
                            <td class="px-3 py-2 text-muted">{to_string(bucket["sets"])}</td>
                            <td class="px-3 py-2 text-muted">{Format.percent(bucket["win_rate"])}</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </.table>
                  <% end %>
                </.card>
              <% end %>
            </div>

            <section>
              <h2 class="font-display text-xl font-semibold text-ink">Head to head</h2>
              <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <.stat label="Sets played" value={to_string(@head_to_head["sets"])} />
                <.stat
                  label={(@player_a["gamer_tag"] || "Player A") <> " wins"}
                  value={to_string(@head_to_head["player_a_wins"])}
                />
                <.stat
                  label={(@player_b["gamer_tag"] || "Player B") <> " wins"}
                  value={to_string(@head_to_head["player_b_wins"])}
                />
                <.stat label="Unresolved sets" value={to_string(@head_to_head["unresolved_sets"])} />
              </div>
              <p class="mt-3 text-xs text-faint">
                {to_string(@events_overlap)} shared events
              </p>
            </section>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
