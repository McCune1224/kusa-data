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
      <div class="animate-fade-up space-y-6">
        <div class="flex items-center justify-between border-y border-[var(--border)] py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-[var(--muted)]">
          <span><span class="mr-2 inline-block size-2 rounded-full bg-[var(--accent)]"></span>Live bracket index</span>
          <span class="hidden sm:inline">Your tournaments</span>
          <span class="text-[var(--accent)]">06 — Saved</span>
        </div>

        <section class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
              Browse
            </.btn>
            <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-[var(--accent)]">
              {if @current_user, do: @current_user.email, else: "Your account"}
            </p>
            <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-[var(--text)] sm:text-5xl">
              Your tournaments
            </h1>
            <p class="mt-2 max-w-xl text-[15px] leading-relaxed text-[var(--muted)]">
              Bookmarked brackets, with the last fetched snapshot when start.gg is offline.
            </p>
          </div>
          <div class="hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface)]/60 px-4 py-3 sm:block">
            <p class="font-mono text-xs uppercase tracking-[0.16em] text-[var(--muted)]">
              Bento grid
            </p>
            <p class="mt-1 text-sm font-semibold text-[var(--text)]">{length(@tournaments)} saved</p>
          </div>
        </section>

        <section>
          <%= if @loading do %>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <.skeleton :for={_ <- 1..6} class="h-44 w-full rounded-[20px]" />
            </div>
          <% else %>
            <div id="bookmarks" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div
                id="bookmarks-empty"
                class="hidden rounded-[20px] border border-dashed border-[var(--border)] px-6 py-14 text-center only:block"
              >
                <div class="mx-auto flex size-10 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface)] text-[var(--muted)]">
                  <.icon name="hero-bookmark" class="size-5" />
                </div>
                <p class="mt-3 text-sm font-medium text-[var(--text)]">Nothing saved yet</p>
                <p class="mt-1 text-sm text-[var(--muted)]">Bookmark a tournament to pin it here.</p>
              </div>
              <div :for={{id, bookmark} <- @streams.bookmarks} id={id} class="h-full">
                <div class="group flex h-full flex-col rounded-[20px] border border-[var(--border)] bg-[var(--surface)]/80 p-5 backdrop-blur transition-colors hover:border-[var(--border2)] hover:bg-[var(--surface2)]/70">
                  <div class="flex items-start justify-between gap-3">
                    <span class="rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2.5 py-1 font-mono text-[10px] uppercase tracking-[0.14em] text-[var(--muted)]">{date_badge(
                      bookmark
                    )}</span>
                    <button
                      type="button"
                      phx-click="unbookmark"
                      phx-value-slug={bookmark["tournament_slug"]}
                      class="flex size-7 shrink-0 items-center justify-center rounded-full border border-[var(--border)] text-[var(--muted)] transition-colors hover:border-rose-500/30 hover:text-rose-300"
                      aria-label="Remove bookmark"
                    ><.icon name="hero-bookmark-slash" class="size-3.5" /></button>
                  </div>
                  <.link navigate={~p"/tournament/#{bare_slug(bookmark["slug"])}"} class="mt-4 block">
                    <h3 class="line-clamp-2 text-[16px] font-semibold leading-snug text-[var(--text)] transition-colors group-hover:text-white">
                      {bookmark["name"] || "Saved tournament"}
                    </h3>
                  </.link>
                  <div class="mt-3 flex flex-wrap gap-2">
                    <span class="inline-flex items-center gap-1.5 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2.5 py-1 text-xs text-[var(--muted)]"><.icon
                      name="hero-map-pin"
                      class="size-3.5 text-[var(--muted)]"
                    />{bookmark["city"] || bookmark["venueName"] || "—"}</span>
                    <span class="inline-flex items-center gap-1.5 rounded-full border border-[var(--border)] bg-[var(--surface2)] px-2.5 py-1 text-xs text-[var(--muted)]"><.icon
                      name="hero-calendar-days"
                      class="size-3.5 text-[var(--muted)]"
                    />{bookmark["slug"] |> bare_slug() |> String.slice(0, 24)}</span>
                  </div>
                  <div class="mt-4 flex items-center justify-between border-t border-[var(--border)] pt-3">
                    <span class="text-xs font-medium text-[var(--muted)]">Saved bracket</span>
                    <span class="inline-flex items-center gap-1 text-xs font-semibold text-[var(--accent)]">View
                    <.icon name="hero-arrow-up-right" class="size-3" /></span>
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
