defmodule KusaDataWeb.LeaguesLive do
  use KusaDataWeb, :live_view

  alias KusaData.Leagues

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nav: :leagues,
       leagues: [],
       loading: true,
       form: to_form(%{"name" => ""})
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = spawn_load(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:leagues_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    {:noreply, assign(socket, leagues: result, loading: false, load_ref: nil)}
  end

  def handle_info({:leagues_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_load(socket) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:leagues_loaded, ref, Leagues.for_owner(socket.assigns.current_user)})
    end)

    assign(socket, load_ref: ref)
  end

  @impl true
  def handle_event("create", %{"name" => name}, socket) do
    case Leagues.create_league(socket.assigns.current_user, %{name: name}) do
      {:ok, league} ->
        {:noreply,
         socket
         |> put_flash(:info, "League created.")
         |> push_navigate(to: "/leagues/#{league.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div class="animate-fade-up space-y-6">
        <div class="flex items-center justify-between border-y border-[var(--border)] py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-[var(--muted)]">
          <span><span class="mr-2 inline-block size-2 rounded-full bg-[var(--accent)]"></span>Live bracket index</span>
          <span class="hidden sm:inline">Leagues</span>
          <span class="text-[var(--accent)]">07 — Teams</span>
        </div>

        <section class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
              Browse
            </.btn>
            <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-[var(--accent)]">
              League concept
            </p>
            <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-[var(--text)] sm:text-5xl">
              Your leagues
            </h1>
            <p class="mt-2 max-w-xl text-[15px] leading-relaxed text-[var(--muted)]">
              Group linked tournaments into seasons and rank members, Braacket-style.
            </p>
          </div>
          <div class="hidden rounded-[16px] border border-[var(--border)] bg-[var(--surface)]/60 px-4 py-3 sm:block">
            <p class="font-mono text-xs uppercase tracking-[0.16em] text-[var(--muted)]">
              Season standings
            </p>
            <p class="mt-1 text-sm font-semibold text-[var(--text)]">Braacket-style</p>
          </div>
        </section>

        <section class="grid gap-4 lg:grid-cols-[0.85fr_1.15fr]">
          <div class="rounded-[20px] border border-[var(--border)] bg-[var(--surface)]/80 p-6 backdrop-blur">
            <h2 class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
              New league
            </h2>
            <p class="mt-2 text-sm leading-relaxed text-[var(--muted)]">
              Create a circuit, then import tournaments to auto-link members.
            </p>
            <.form for={@form} id="league-form" phx-submit="create" class="mt-5 space-y-3">
              <.input
                field={@form[:name]}
                type="text"
                placeholder="Midwest Melee Circuit"
                class="h-11 w-full rounded-full border border-[var(--border)] bg-[var(--surface2)] px-4 text-sm text-[var(--text)] placeholder:text-[var(--muted)]"
              />
              <.btn variant="primary" type="submit" class="w-full rounded-full">Create league</.btn>
            </.form>
          </div>

          <div class="rounded-[20px] border border-[var(--border)] bg-[var(--surface2)]/60 p-6 backdrop-blur">
            <div class="flex items-center justify-between">
              <h2 class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
                Your leagues
              </h2>
              <span class="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2.5 py-1 font-mono text-[11px] text-[var(--muted)]">{length(
                @leagues
              )} total</span>
            </div>
            <div class="mt-4">
              <%= if @loading do %>
                <div class="grid gap-3 sm:grid-cols-2">
                  <.skeleton :for={_ <- 1..4} class="h-24 w-full rounded-[16px]" />
                </div>
              <% else %>
                <div class="grid gap-3 sm:grid-cols-2">
                  <div
                    :for={league <- @leagues}
                    class="group rounded-[16px] border border-[var(--border)] bg-[var(--surface)]/80 p-4 backdrop-blur transition-colors hover:border-[var(--border2)] hover:bg-[var(--surface)]"
                  >
                    <.link navigate={~p"/leagues/#{league.id}"} class="flex h-full flex-col gap-3">
                      <div class="flex items-start justify-between gap-3">
                        <span class="flex size-9 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface2)] text-xs font-bold text-[var(--text)]">{String.slice(
                          league.name || "?",
                          0,
                          1
                        )
                        |> String.upcase()}</span>
                        <span class="flex size-7 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface)] text-[var(--muted)] transition-colors group-hover:border-[var(--accent)]/40 group-hover:text-[var(--accent)]"><.icon
                          name="hero-arrow-up-right"
                          class="size-3.5"
                        /></span>
                      </div>
                      <span class="line-clamp-2 text-[15px] font-semibold leading-snug text-[var(--text)] group-hover:text-white">{league.name}</span>
                      <span class="mt-auto inline-flex items-center gap-1.5 text-xs text-[var(--muted)]"><span class="size-1.5 rounded-full bg-[var(--accent)]"></span>
                      Open standings</span>
                    </.link>
                  </div>
                  <div
                    :if={@leagues == []}
                    class="col-span-full rounded-[16px] border border-dashed border-[var(--border)] px-6 py-10 text-center text-sm text-[var(--muted)]"
                  >
                    No leagues yet — create one to start importing tournaments.
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
