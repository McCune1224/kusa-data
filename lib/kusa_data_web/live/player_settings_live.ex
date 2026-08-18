defmodule KusaDataWeb.PlayerSettingsLive do
  use KusaDataWeb, :live_view

  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries
  alias KusaData.PlayerLinks
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :your,
       card: nil,
       card_error: nil,
       aliases: [],
       results: [],
       search_form: to_form(%{"tournament" => "", "tag" => ""}),
       alias_form: to_form(%{"player_id" => "", "alias" => ""}),
       link_form: to_form(%{"player_id" => "", "confirm" => "false"}),
       message: nil
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = spawn_load(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:settings_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    {:noreply, assign(socket, card: result, card_error: nil, load_ref: nil)}
  end

  def handle_info({:settings_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket) do
    ref = make_ref()
    parent = self()
    user = socket.assigns.current_user

    Task.start(fn ->
      card =
        if user.linked_player_id do
          case Players.card(user.linked_player_id) do
            {:ok, summary, _} -> {:ok, summary}
            error -> error
          end
        else
          nil
        end

      send(parent, {:settings_loaded, ref, %{card: card, aliases: PlayerLinks.aliases(user)}})
    end)

    assign(socket, load_ref: ref)
  end

  @impl true
  def handle_event("search", %{"tournament" => tournament, "tag" => tag}, socket) do
    results =
      if tournament != "" and tag != "" do
        case Client.query(Queries.participant_search(tournament, tag, 10)) do
          {:ok, data} -> data["tournament"]["participants"]["nodes"] || []
          _ -> []
        end
      else
        []
      end

    {:noreply,
     assign(socket,
       results: results,
       search_form: to_form(%{"tournament" => tournament, "tag" => tag})
     )}
  end

  @impl true
  def handle_event("link", %{"player_id" => player_id}, socket) do
    player_id = parse_int(player_id)

    case PlayerLinks.link_player(socket.assigns.current_user, player_id) do
      {:ok, _user} ->
        {:noreply,
         socket |> put_flash(:info, "Linked player updated.") |> push_patch(to: "/settings")}

      {:error, :confirmation_required} ->
        {:noreply,
         socket
         |> assign(message: {:confirm, player_id})
         |> put_flash(:info, "You already have a linked player — confirm to change it.")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("link-confirmed", %{"player_id" => player_id}, socket) do
    case PlayerLinks.link_player(socket.assigns.current_user, parse_int(player_id), confirm: true) do
      {:ok, _user} ->
        {:noreply,
         socket |> put_flash(:info, "Linked player changed.") |> push_patch(to: "/settings")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add-alias", %{"player_id" => player_id, "alias" => alias_name}, socket) do
    case PlayerLinks.add_alias(socket.assigns.current_user, parse_int(player_id), alias_name) do
      {:ok, _alias_row} ->
        {:noreply, socket |> put_flash(:info, "Alias added.") |> push_patch(to: "/settings")}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           message: {:alias_error, Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)}
         )}
    end
  end

  @impl true
  def handle_event("remove-alias", %{"id" => id}, socket) do
    PlayerLinks.remove_alias(socket.assigns.current_user, parse_int(id))
    {:noreply, socket |> put_flash(:info, "Alias removed.") |> push_patch(to: "/settings")}
  end

  @impl true
  def handle_event("merge-aliases", _params, socket) do
    {_kept, removed} = PlayerLinks.merge_duplicate_aliases(socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Merged #{removed} duplicate aliases.")
     |> push_patch(to: "/settings")}
  end

  defp parse_int(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
          Browse
        </.btn>

        <div class="mt-5">
          <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
            Player settings
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-stone-50">
            Link your profile
          </h1>
          <p class="mt-1 text-[15px] text-stone-400">
            One canonical start.gg player id plus aliases, so one tag has a single profile.
          </p>
        </div>

        <div class="mt-8 grid gap-6 lg:grid-cols-2">
          <div class="space-y-6">
            <.card class="p-5">
              <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                Linked player
              </h2>

              <%= if @card && @card[:card] do %>
                <div class="mt-4 flex items-center gap-4">
                  <.avatar name={@card[:card]["gamer_tag"]} class="size-12 text-base" />
                  <div class="min-w-0">
                    <div class="truncate text-lg font-semibold text-stone-100">
                      {@card[:card]["gamer_tag"]}
                    </div>
                    <div class="font-mono text-[13px] text-stone-400">
                      player {@card[:card]["player_id"]} · {@card[:card]["wins"]}W-{@card[:card][
                        "losses"
                      ]}L
                    </div>
                    <div class="mt-1 text-sm text-stone-500">
                      best finish
                      <%= if @card[:card]["finishes"] != [] do %>
                        ##{@card[:card]["finishes"] |> Enum.map(& &1["placement"]) |> Enum.min()}
                      <% else %>
                        —
                      <% end %>
                    </div>
                  </div>
                  <.link
                    navigate={~p"/player/#{@card[:card]["player_id"]}"}
                    class="ml-auto shrink-0 rounded-none border border-stone-700/70 px-2.5 py-1 font-mono text-xs text-stone-400 transition-colors hover:text-stone-100"
                  >
                    Profile
                  </.link>
                </div>
              <% else %>
                <p class="mt-4 text-sm text-stone-500">No player linked yet.</p>
              <% end %>

              <div class="mt-6 border-t border-stone-800/70 pt-5">
                <h3 class="text-xs font-medium uppercase tracking-[0.16em] text-stone-500">
                  Find your player
                </h3>
                <.form
                  for={@search_form}
                  id="player-search-form"
                  phx-submit="search"
                  class="mt-3 space-y-3"
                >
                  <div class="flex gap-2">
                    <.input
                      field={@search_form[:tournament]}
                      type="text"
                      placeholder="tournament slug"
                      class="h-10 w-1/2 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                    <.input
                      field={@search_form[:tag]}
                      type="text"
                      placeholder="gamer tag"
                      class="h-10 w-1/2 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                    />
                  </div>
                  <.btn variant="primary" type="submit" class="rounded-none w-full">Search</.btn>
                </.form>

                <div class="mt-3 space-y-1">
                  <div
                    :for={participant <- @results}
                    class="flex items-center justify-between gap-3 rounded-md px-3 py-2.5 hover:bg-stone-900/60"
                  >
                    <span class="min-w-0 truncate text-[15px] text-stone-300">
                      {participant["prefix"] && "#{participant["prefix"]} | "}{participant["gamerTag"]}
                    </span>
                    <button
                      type="button"
                      phx-click="link"
                      phx-value-player_id={participant["user"]["player"]["id"]}
                      class="shrink-0 rounded-none border border-lime-400/40 px-2 py-1 text-xs font-semibold text-lime-300 transition-colors hover:bg-lime-400 hover:text-stone-950"
                    >
                      Link
                    </button>
                  </div>
                  <div :if={@results == []} class="text-sm text-stone-600">
                    Search a tournament and tag to find your player.
                  </div>
                </div>

                <%= if match?({:confirm, _}, @message) do %>
                  <div class="mt-3 rounded-xl border border-amber-500/40 bg-amber-500/10 p-4">
                    <p class="text-sm text-amber-200">
                      This replaces your current linked player. Confirm the change:
                    </p>
                    <button
                      type="button"
                      phx-click="link-confirmed"
                      phx-value-player_id={elem(@message, 1)}
                      class="mt-3 rounded-none border border-amber-400/60 px-3 py-1.5 text-xs font-semibold text-amber-200 transition-colors hover:bg-amber-400 hover:text-stone-950"
                    >
                      Confirm change
                    </button>
                  </div>
                <% end %>
              </div>
            </.card>
          </div>

          <div class="space-y-6">
            <.card class="p-5">
              <div class="flex items-center justify-between gap-3">
                <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
                  Aliases
                </h2>
                <.btn
                  variant="ghost"
                  size="sm"
                  phx-click="merge-aliases"
                  icon="hero-arrows-right-left"
                >
                  Merge duplicates
                </.btn>
              </div>

              <div class="mt-4 space-y-1">
                <div
                  :for={alias_row <- @card[:aliases] || []}
                  class="flex items-center justify-between gap-3 rounded-md px-3 py-2.5 hover:bg-stone-900/60"
                >
                  <span class="truncate text-[15px] text-stone-300">{alias_row.alias}</span>
                  <span class="font-mono text-xs text-stone-500">player {alias_row.player_id}</span>
                  <button
                    type="button"
                    phx-click="remove-alias"
                    phx-value-id={alias_row.id}
                    class="shrink-0 text-stone-500 transition-colors hover:text-rose-400"
                    aria-label="Remove alias"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>
                <div :if={(@card[:aliases] || []) == []} class="text-sm text-stone-600">
                  No aliases yet.
                </div>
              </div>

              <.form
                for={@alias_form}
                id="alias-form"
                phx-submit="add-alias"
                class="mt-4 flex gap-2"
              >
                <.input
                  field={@alias_form[:player_id]}
                  type="text"
                  placeholder="player id"
                  class="h-10 w-28 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                />
                <.input
                  field={@alias_form[:alias]}
                  type="text"
                  placeholder="alias tag"
                  class="h-10 flex-1 rounded-none border border-stone-700/70 bg-stone-950 px-3 text-sm"
                />
                <.btn variant="secondary" type="submit" class="rounded-none">Add</.btn>
              </.form>
            </.card>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
