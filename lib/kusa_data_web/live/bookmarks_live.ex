defmodule KusaDataWeb.BookmarksLive do
  use KusaDataWeb, :live_view

  alias KusaData.Bookmarks
  alias KusaData.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(nav: :your, loading: true, error: nil, tournaments: [])
     |> stream_configure(:bookmarks,
       dom_id: fn b -> "bookmark-#{b["tournament_slug"] |> String.replace("/", "-")}" end
     )
     |> stream(:bookmarks, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = spawn_load(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:bookmarks_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    case result do
      {:ok, tournaments, _status} ->
        rows = Enum.map(tournaments, &Map.put(&1, "slug", &1["tournament_slug"]))

        {:noreply,
         assign(socket, loading: false, tournaments: rows)
         |> stream(:bookmarks, rows, reset: true)}

      {:error, reason} ->
        {:noreply,
         assign(socket, loading: false, error: reason) |> stream(:bookmarks, [], reset: true)}
    end
  end

  def handle_info({:bookmarks_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket) do
    ref = make_ref()
    parent = self()
    user = socket.assigns.current_user

    Task.start(fn ->
      send(parent, {:bookmarks_loaded, ref, load_bookmarks(user)})
    end)

    assign(socket, load_ref: ref)
  end

  defp load_bookmarks(user) do
    bookmarks = Bookmarks.for_user(user)

    results =
      Enum.reduce_while(bookmarks, {:ok, []}, fn bookmark, {:ok, acc} ->
        case Tournaments.by_slug(bookmark.tournament_slug) do
          {:ok, tournament, _} ->
            {:cont, {:ok, [Map.merge(bookmark_snapshot(bookmark), tournament) | acc]}}

          {:error, _reason} ->
            # start.gg unavailable: render the stored snapshot instead.
            {:cont,
             {:ok,
              [
                Map.merge(bookmark_snapshot(bookmark), %{"slug" => bookmark.tournament_slug})
                | acc
              ]}}
        end
      end)

    case results do
      {:ok, tournaments} -> {:ok, Enum.reverse(tournaments), :miss}
      error -> error
    end
  end

  defp bookmark_snapshot(bookmark) do
    Map.new(bookmark.tournament_snapshot || %{}, fn {k, v} -> {to_string(k), v} end)
  end

  @impl true
  def handle_event("unbookmark", %{"slug" => slug}, socket) do
    Bookmarks.unbookmark(socket.assigns.current_user, slug)

    {:noreply,
     socket
     |> put_flash(:info, "Removed from your tournaments.")
     |> push_patch(to: "/your-tournaments")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="desk-grid animate-fade-up">
        <div class="mb-5 flex items-center justify-between border-y border-stone-800 py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-stone-500">
          <span><span class="mr-2 inline-block size-2 bg-lime-400"></span>Live bracket index</span>
          <span class="hidden sm:inline">Your tournaments</span>
          <span class="text-orange-300">06 — Saved</span>
        </div>

        <section>
          <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
            Browse
          </.btn>
          <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-lime-300">
            {if @current_user, do: @current_user.email, else: "Your account"}
          </p>
          <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-stone-50 sm:text-5xl">
            Your tournaments
          </h1>
          <p class="mt-2 text-[15px] text-stone-400">
            Bookmarked brackets, with the last fetched snapshot when start.gg is offline.
          </p>
        </section>

        <section class="mt-10">
          <%= if @loading do %>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <.skeleton :for={_ <- 1..3} class="h-40 rounded-none" />
            </div>
          <% else %>
            <div id="bookmarks" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div
                id="bookmarks-empty"
                class="hidden border border-dashed border-stone-800 px-6 py-12 text-center text-[15px] text-stone-400 only:block"
              >
                Nothing saved yet — bookmark a tournament to pin it here.
              </div>

              <div :for={{id, bookmark} <- @streams.bookmarks} id={id} class="h-full">
                <div class="flex h-full flex-col border border-stone-800 bg-stone-900/40 p-5 transition-colors hover:border-stone-600">
                  <div class="flex items-start justify-between gap-3">
                    <.link
                      navigate={~p"/tournament/#{bare_slug(bookmark["slug"])}"}
                      class="min-w-0"
                    >
                      <h3 class="line-clamp-2 text-lg font-medium leading-snug text-stone-200 hover:text-stone-50">
                        {bookmark["name"] || "Saved tournament"}
                      </h3>
                    </.link>
                    <button
                      type="button"
                      phx-click="unbookmark"
                      phx-value-slug={bookmark["tournament_slug"]}
                      class="shrink-0 text-stone-500 transition-colors hover:text-rose-400"
                      aria-label="Remove bookmark"
                    >
                      <.icon name="hero-bookmark-slash" class="size-4" />
                    </button>
                  </div>

                  <div class="mt-4 flex-1 space-y-2 text-[15px] text-stone-400">
                    <span class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="size-3.5 text-stone-600" />
                      {bookmark["city"] || bookmark["venueName"] || "—"}
                    </span>
                    <span class="flex items-center gap-2">
                      <.icon name="hero-calendar-days" class="size-3.5 text-stone-600" />
                      {date_badge(bookmark)}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp date_badge(bookmark) do
    timezone = bookmark["timezone"] || "UTC"

    case bookmark["startAt"] do
      nil -> "TBA"
      unix -> short_date(unix, timezone)
    end
  end
end
