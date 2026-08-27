defmodule KusaDataWeb.PlayerH2HLive do
  @moduledoc """
  Head-to-head record between the URL player (`:id`) and a chosen opponent.
  """
  use KusaDataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       player_id: nil,
       opponent_id: nil,
       form: to_form(%{}, as: :h2h),
       h2h: nil,
       error: nil
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply, assign(socket, player_id: parse_id(id), form: to_form(%{}, as: :h2h))}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("lookup", params, socket) do
    opponent = params["opponent"] || get_in(params, ["h2h", "opponent"])
    player_id = socket.assigns.player_id

    case {player_id, parse_id(opponent)} do
      {nil, _} ->
        {:noreply, assign(socket, error: "Player not found.")}

      {_, nil} ->
        {:noreply, assign(socket, error: "Enter a numeric opponent player ID.")}

      {player_a, player_b} ->
        {:noreply,
         socket
         |> assign(:opponent_id, player_b)
         |> assign(:error, nil)
         |> assign(:h2h, safe_h2h(player_a, player_b))}
    end
  end

  defp safe_h2h(player_a, player_b) do
    case KusaData.Players.head_to_head(player_a, player_b, %{}) do
      {:ok, record, _} ->
        record

      {:error, _} ->
        %{"sets" => 0, "player_a_wins" => 0, "player_b_wins" => 0, "unresolved_sets" => 0}
    end
  end

  defp parse_id(nil), do: nil

  defp parse_id(value) when is_binary(value) do
    case String.trim(value) |> Integer.parse() do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_id(value) when is_integer(value), do: value
  defp parse_id(_), do: nil

  defp player_h2h_id(nil), do: "player-h2h"
  defp player_h2h_id(player_id), do: "player-h2h-#{player_id}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:players}>
      <div id={player_h2h_id(@player_id)} class="mx-auto flex max-w-3xl flex-col gap-8">
        <header class="flex flex-col gap-1">
          <span class="inline-flex w-fit items-center gap-2 rounded-none border border-accent-line bg-accent-soft px-3 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-accent">
            <span class="hero-squares-2x2 size-3.5"></span> Head-to-head
          </span>
          <h1 class="mt-3 font-display text-3xl font-bold tracking-tight text-ink sm:text-4xl">
            Player matchup
          </h1>
          <p class="text-sm text-muted">
            Compare the record for player
            <%= if @player_id do %>
              <span class="font-semibold text-ink">#{@player_id}</span>
            <% else %>
              <span class="font-semibold text-ink">—</span>
            <% end %>
            against any opponent.
          </p>
        </header>

        <.card>
          <.form
            for={@form}
            id="player-h2h-form"
            phx-submit="lookup"
            class="flex flex-col gap-4 sm:flex-row sm:items-end"
          >
            <.input
              field={@form[:opponent]}
              id="opponent"
              name="opponent"
              type="text"
              label="Opponent player ID"
              placeholder="e.g. 123456"
            />
            <.button type="submit" class="shrink-0">Look up</.button>
          </.form>
        </.card>

        <%= if @error do %>
          <div class="rounded-none border border-danger/50 bg-danger-soft px-4 py-3 text-sm text-danger">
            {@error}
          </div>
        <% end %>

        <%= if @h2h do %>
          <section class="flex flex-col gap-4">
            <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <.stat
                label={"Player #" <> to_string(@player_id) <> " wins"}
                value={to_string(@h2h["player_a_wins"])}
                sub={"losses: #{@h2h["player_b_wins"]}"}
              />
              <.stat
                label={"Opponent #" <> to_string(@opponent_id) <> " wins"}
                value={to_string(@h2h["player_b_wins"])}
                sub={"losses: #{@h2h["player_a_wins"]}"}
              />
              <.stat label="Total sets" value={to_string(@h2h["sets"])} />
              <.stat
                label="Unresolved sets"
                value={to_string(@h2h["unresolved_sets"])}
                sub="name-only, uncounted"
              />
            </div>

            <div class="rounded-none border border-line bg-surface px-5 py-4 text-sm">
              <p class="flex flex-wrap items-center gap-2 text-muted">
                <span class="font-semibold text-ink">Player #{@player_id}</span>
                <span class="text-faint">{@h2h["player_a_wins"]} – {@h2h["player_b_wins"]}</span>
                <span class="font-semibold text-ink">Opponent #{@opponent_id}</span>
                <span class="text-faint">
                  across {@h2h["sets"]} set{if @h2h["sets"] != 1, do: "s"}
                </span>
              </p>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
