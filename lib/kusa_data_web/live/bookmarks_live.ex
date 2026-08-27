defmodule KusaDataWeb.BookmarksLive do
  @moduledoc """
  "Your tournaments": the authenticated user's saved/bookmarked tournaments.

  Loads the current user's bookmarks (newest first) and renders a card per
  saved tournament, using the stored snapshot so the page still renders when
  start.gg is unavailable. A per-card "Remove" control unbookmarks the
  tournament and reloads the list in place.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Bookmarks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, bookmarks: [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:bookmarks, Bookmarks.for_user(user))
      |> assign(:page_title, "Saved tournaments")

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove", %{"slug" => slug}, socket) do
    user = socket.assigns.current_user
    :ok = Bookmarks.unbookmark(user, slug)

    {:noreply, assign(socket, :bookmarks, Bookmarks.for_user(user))}
  end

  # The tournament node is stored on the bookmark as `tournament_snapshot`.
  # Fall back to an empty map so the card always renders (it tolerates a
  # missing slug/name) rather than raising on a legacy empty snapshot.
  defp tournament_node(%{tournament_snapshot: snapshot})
       when is_map(snapshot) and snapshot != %{},
       do: snapshot

  defp tournament_node(_bookmark), do: %{}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:your}>
      <div id="bookmarks-live" class="flex flex-col gap-8">
        <header class="flex flex-col gap-1">
          <h1 class="font-display text-3xl font-bold tracking-tight text-ink">
            Saved tournaments
          </h1>
          <p class="max-w-2xl text-sm text-muted">
            Tournaments you've bookmarked. We keep a snapshot so they stay here
            even when start.gg is quiet.
          </p>
        </header>

        <%= if Enum.empty?(@bookmarks) do %>
          <.empty
            icon="hero-bookmark"
            title="No saved tournaments"
            description="Bookmark tournaments to find them here."
          />
        <% else %>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for bookmark <- @bookmarks do %>
              <div class="flex flex-col gap-2">
                <.tournament_card tournament={tournament_node(bookmark)} />

                <div class="flex justify-end">
                  <.button
                    phx-click="remove"
                    phx-value-slug={bookmark.tournament_slug}
                    variant={:ghost}
                    size={:sm}
                  >
                    <.icon name="hero-x-mark" class="size-4" /> Remove
                  </.button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
