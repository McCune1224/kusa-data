defmodule KusaDataWeb.PlayerSettingsLive do
  @moduledoc """
  Player settings: link a start.gg player profile and manage the gamer-tag
  aliases that map to it.
  """
  use KusaDataWeb, :live_view

  alias KusaData.PlayerLinks

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       aliases: [],
       linked_player_id: nil,
       confirm_link: nil,
       form: to_form(%{}, as: :alias),
       link_form: to_form(%{}, as: :link)
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:aliases, load_aliases(user))
      |> assign(:linked_player_id, user.linked_player_id)
      |> assign(:confirm_link, nil)
      |> assign(:form, to_form(%{"player_id" => "", "name" => ""}, as: :alias))
      |> assign(:link_form, to_form(%{"player_id" => ""}, as: :link))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id="settings-live" class="mx-auto flex max-w-3xl flex-col gap-8">
        <header class="flex flex-col gap-1">
          <h1 class="font-display text-2xl font-semibold tracking-tight text-ink">Player settings</h1>
          <p class="text-sm text-muted">
            Link your start.gg player profile and manage the gamer tags that map to it.
          </p>
        </header>

        <.card class="p-6">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="font-display text-lg font-semibold text-ink">Linked player</h2>
              <p class="mt-1 text-sm text-muted">
                <%= if @linked_player_id do %>
                  Currently linked to player <.link
                    navigate={~p"/player/#{@linked_player_id}"}
                    class="text-accent transition-colors hover:underline"
                  >
                    #<%= @linked_player_id %>
                  </.link>.
                <% else %>
                  No player linked yet.
                <% end %>
              </p>
            </div>
          </div>

          <.form
            for={@link_form}
            id="link-player-form"
            phx-submit="link_player"
            class="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end"
          >
            <.input
              field={@link_form[:player_id]}
              label="Player ID"
              type="number"
              placeholder="start.gg player id"
            />
            <.button type="submit" variant="primary">Link player</.button>
          </.form>

          <%= if @confirm_link do %>
            <div class="mt-4 rounded-card border border-accent-line bg-accent-soft px-4 py-3 text-sm text-ink">
              <p>
                You already have a linked player. Linking to
                <span class="font-semibold">#{@confirm_link}</span>
                will replace the existing link.
              </p>
              <.form
                for={@link_form}
                id="confirm-link-form"
                phx-submit="confirm_link"
                class="mt-3 flex items-center gap-2"
              >
                <input type="hidden" name="player_id" value={to_string(@confirm_link)} />
                <.button type="submit" variant="danger" size="sm">Replace linked player</.button>
                <button
                  type="button"
                  phx-click="cancel_link"
                  class="rounded-card px-3 py-1.5 text-sm font-semibold text-muted transition-colors hover:bg-surface-2 hover:text-ink"
                >
                  Cancel
                </button>
              </.form>
            </div>
          <% end %>
        </.card>

        <.card class="p-6">
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="font-display text-lg font-semibold text-ink">Aliases</h2>
              <p class="mt-1 text-sm text-muted">Gamer tags that point to your linked player.</p>
            </div>
            <button
              type="button"
              phx-click="merge_duplicates"
              class="inline-flex items-center gap-2 rounded-card border border-line-2 bg-surface-2 px-3 py-1.5 text-sm font-semibold text-ink transition-colors hover:border-accent-line hover:text-accent"
            >
              <.icon name="hero-arrow-path" class="size-4" /> Merge duplicates
            </button>
          </div>

          <%= if Enum.empty?(@aliases) do %>
            <.empty
              class="mt-6"
              icon="hero-tag"
              title="No aliases yet"
              description="Add a gamer tag below to get started."
            />
          <% else %>
            <.table class="mt-4">
              <table>
                <thead>
                  <tr class="border-b border-line text-left text-xs uppercase tracking-[0.08em] text-faint">
                    <th class="px-4 py-2 font-medium">Alias</th>
                    <th class="px-4 py-2 font-medium">Player ID</th>
                    <th class="px-4 py-2 text-right font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for alias_row <- @aliases do %>
                    <tr class="border-b border-line transition-colors hover:bg-surface-2">
                      <td class="px-4 py-3 text-ink">{alias_row.alias}</td>
                      <td class="px-4 py-3 text-muted">{alias_row.player_id}</td>
                      <td class="px-4 py-3 text-right">
                        <button
                          type="button"
                          phx-click="remove_alias"
                          phx-value-id={to_string(alias_row.id)}
                          aria-label={"Remove " <> alias_row.alias}
                          class="inline-flex size-9 items-center justify-center rounded-card border border-line bg-surface-2 text-muted transition-colors hover:border-danger/40 hover:text-danger"
                        >
                          <.icon name="hero-x-mark" class="size-4" />
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </.table>
          <% end %>

          <.form
            for={@form}
            id="add-alias-form"
            phx-submit="add_alias"
            class="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end"
          >
            <.input
              field={@form[:player_id]}
              label="Player ID"
              type="number"
              placeholder="Player ID"
            />
            <.input field={@form[:name]} label="Alias" type="text" placeholder="Gamer tag" />
            <.button type="submit" variant="primary">Add alias</.button>
          </.form>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("add_alias", %{"alias" => %{"player_id" => pid, "name" => name}}, socket) do
    user = socket.assigns.current_user

    socket =
      case parse_player_id(pid) do
        {:ok, player_id} ->
          case PlayerLinks.add_alias(user, player_id, name) do
            {:ok, _} ->
              reload(socket)
              |> put_flash(:info, "Alias added.")
              |> assign(:form, to_form(%{"player_id" => "", "name" => ""}, as: :alias))

            {:error, changeset} ->
              assign(socket, form: to_form(%{"player_id" => pid, "name" => name}, as: :alias))
              |> put_flash(:error, error_message({:error, changeset}))
          end

        :error ->
          assign(socket, form: to_form(%{"player_id" => pid, "name" => name}, as: :alias))
          |> put_flash(:error, "Enter a valid player id (numbers only).")
      end

    {:noreply, socket}
  end

  def handle_event("link_player", %{"link" => %{"player_id" => pid}}, socket) do
    user = socket.assigns.current_user

    socket =
      case parse_player_id(pid) do
        {:ok, player_id} ->
          case PlayerLinks.link_player(user, player_id) do
            {:ok, _} ->
              reload(socket) |> put_flash(:info, "Player linked.")

            {:error, :confirmation_required} ->
              assign(socket, confirm_link: player_id)

            {:error, _} ->
              put_flash(socket, :error, "Could not link player.")
          end

        :error ->
          put_flash(socket, :error, "Enter a valid player id (numbers only).")
      end

    {:noreply, socket}
  end

  def handle_event("confirm_link", %{"player_id" => pid}, socket) do
    user = socket.assigns.current_user

    socket =
      case parse_player_id(pid) do
        {:ok, player_id} ->
          case PlayerLinks.link_player(user, player_id, confirm: true) do
            {:ok, _} ->
              reload(socket)
              |> assign(:confirm_link, nil)
              |> put_flash(:info, "Player linked.")

            {:error, _} ->
              put_flash(socket, :error, "Could not link player.")
          end

        :error ->
          put_flash(socket, :error, "Enter a valid player id (numbers only).")
      end

    {:noreply, socket}
  end

  def handle_event("cancel_link", _params, socket) do
    {:noreply, assign(socket, confirm_link: nil)}
  end

  def handle_event("remove_alias", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    socket =
      case parse_player_id(id) do
        {:ok, alias_id} ->
          case PlayerLinks.remove_alias(user, alias_id) do
            {:ok, _} ->
              reload(socket) |> put_flash(:info, "Alias removed.")

            {:error, _} ->
              put_flash(socket, :error, "Could not remove alias.")
          end

        :error ->
          put_flash(socket, :error, "Invalid alias.")
      end

    {:noreply, socket}
  end

  def handle_event("merge_duplicates", _params, socket) do
    user = socket.assigns.current_user
    {_added, removed} = PlayerLinks.merge_duplicate_aliases(user)

    socket =
      reload(socket)
      |> put_flash(:info, "Merged duplicate aliases (#{removed} removed).")

    {:noreply, socket}
  end

  defp load_aliases(user) do
    if PlayerLinks.repo_configured?() do
      PlayerLinks.aliases(user)
    else
      []
    end
  end

  defp reload(socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:aliases, load_aliases(user))
    |> assign(:linked_player_id, user.linked_player_id)
  end

  defp parse_player_id(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_player_id(_value), do: :error

  defp error_message({:error, %{errors: errors}}) when is_list(errors) do
    message =
      errors
      |> Enum.map(fn {field, {msg, _opts}} -> "#{field} #{msg}" end)
      |> Enum.join(", ")

    if message == "", do: "Could not save.", else: message
  end

  defp error_message(_other), do: "Could not save."
end
