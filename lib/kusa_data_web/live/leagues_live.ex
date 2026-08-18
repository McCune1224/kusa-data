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
      <div class="desk-grid animate-fade-up">
        <div class="mb-5 flex items-center justify-between border-y border-stone-800 py-3 text-[10px] font-semibold uppercase tracking-[0.24em] text-stone-500">
          <span><span class="mr-2 inline-block size-2 bg-lime-400"></span>Live bracket index</span>
          <span class="hidden sm:inline">Leagues</span>
          <span class="text-orange-300">07 — Teams</span>
        </div>

        <section>
          <.btn variant="ghost" size="sm" icon="hero-arrow-left" navigate={~p"/"}>
            Browse
          </.btn>
          <p class="mt-4 text-xs font-semibold uppercase tracking-[0.22em] text-lime-300">
            League concept
          </p>
          <h1 class="mt-2 text-4xl font-black uppercase tracking-[-0.05em] text-stone-50 sm:text-5xl">
            Your leagues
          </h1>
          <p class="mt-2 text-[15px] text-stone-400">
            Group linked tournaments into seasons and rank members, Braacket-style.
          </p>
        </section>

        <section class="mt-10 grid gap-6 lg:grid-cols-[0.75fr_1.25fr]">
          <div>
            <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              New league
            </h2>
            <.form for={@form} id="league-form" phx-submit="create" class="mt-4 space-y-3">
              <.input
                field={@form[:name]}
                type="text"
                placeholder="Midwest Melee Circuit"
                class="h-11 w-full rounded-none border border-stone-700/70 bg-stone-950 px-4 text-sm text-stone-200"
              />
              <.btn variant="primary" type="submit" class="rounded-none w-full">Create league</.btn>
            </.form>
          </div>

          <div>
            <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              Your leagues
            </h2>
            <div class="mt-4 space-y-2">
              <%= if @loading do %>
                <.skeleton :for={_ <- 1..3} class="h-16 w-full rounded-none" />
              <% else %>
                <div
                  :for={league <- @leagues}
                  class="rounded-xl border border-stone-800 bg-stone-900/40 p-5 transition-colors hover:border-stone-600"
                >
                  <.link
                    navigate={~p"/leagues/#{league.id}"}
                    class="flex items-center justify-between gap-3"
                  >
                    <span class="text-lg font-medium text-stone-200 hover:text-stone-50">
                      {league.name}
                    </span>
                    <.icon name="hero-arrow-right" class="size-4 text-stone-600" />
                  </.link>
                </div>
                <div :if={@leagues == []} class="text-sm text-stone-600">
                  No leagues yet — create one to start importing tournaments.
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
