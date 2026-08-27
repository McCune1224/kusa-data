defmodule KusaDataWeb.LeaguesLive do
  @moduledoc """
  Owner dashboard for leagues: lists the user's leagues and lets them create
  a new one.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Leagues

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, leagues: [], form: to_form(%{"name" => ""}, as: :league))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :leagues, Leagues.for_owner(user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:leagues}>
      <section id="leagues-live" class="flex flex-col gap-10">
        <header class="flex flex-col gap-2">
          <h1 class="font-display text-3xl font-bold tracking-tight text-ink">Your leagues</h1>
          <p class="max-w-2xl text-sm text-muted">
            Group tournaments into seasons, import results, and track standings for your scene.
          </p>
        </header>

        <section class="rounded-card border border-line bg-surface p-5 sm:p-6">
          <h2 class="font-display text-lg font-semibold text-ink">Create league</h2>
          <.form
            for={@form}
            id="league-form"
            phx-submit="create"
            class="mt-4 flex flex-col gap-4 sm:flex-row sm:items-end"
          >
            <.input
              field={@form[:name]}
              label="Name"
              placeholder="e.g. Pacific Northwest Crew Battle"
              class="sm:flex-1"
            />
            <.button type="submit" class="shrink-0">Create league</.button>
          </.form>
        </section>

        <%= if Enum.empty?(@leagues) do %>
          <.empty
            class="rounded-card border border-line bg-surface"
            icon="hero-user-group"
            title="No leagues yet"
            description="Create your first league above to start organizing tournaments and seasons."
          />
        <% else %>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for league <- @leagues do %>
              <.link
                navigate={~p"/leagues/#{league.id}"}
                class="group flex flex-col gap-2 rounded-card border border-line bg-surface p-5 transition-colors hover:border-accent-line hover:bg-surface-2"
              >
                <span class="font-display text-lg font-semibold text-ink transition-colors group-hover:text-accent">
                  {league.name}
                </span>
                <span class="text-xs text-faint">Created {Format.short_date(
                  DateTime.to_unix(league.created_at)
                )}</span>
              </.link>
            <% end %>
          </div>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create", %{"league" => %{"name" => name}}, socket) do
    user = socket.assigns.current_user

    socket =
      case Leagues.create_league(user, %{name: name}) do
        {:ok, _league} ->
          socket
          |> put_flash(:info, "League created")
          |> assign(:leagues, Leagues.for_owner(user))
          |> assign(:form, to_form(%{"name" => ""}, as: :league))

        {:error, changeset} ->
          assign(socket, :form, to_form(changeset, as: :league))
      end

    {:noreply, socket}
  end
end
