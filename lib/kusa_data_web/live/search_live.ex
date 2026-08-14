defmodule KusaDataWeb.SearchLive do
  use KusaDataWeb, :live_view

  alias KusaData.{Game, Repo, Search}

  @min_chars 2
  @limit 8

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:game, Repo.get_by(Game, key: "melee"))
     |> assign(:query, "")
     |> assign(:results, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    game = socket.assigns.game
    q = String.trim(query)

    results =
      if is_nil(game) || String.length(q) < @min_chars do
        []
      else
        Search.search_index(game, q) |> Enum.take(@limit)
      end

    {:noreply, socket |> assign(:query, q) |> assign(:results, results)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, socket |> assign(:query, "") |> assign(:results, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="space-y-1">
        <h1 class="text-2xl font-bold">Player search</h1>
        <p class="text-sm opacity-70">Find a Melee player by gamer tag or prefix.</p>
      </div>

      <form id="search-form" phx-change="search">
        <div class="relative">
          <input
            type="text"
            name="query"
            value={@query}
            placeholder="Search players…"
            autocomplete="off"
            phx-debounce="300"
            data-test="search-input"
            class="input input-bordered w-full"
          />
          <%= if @query != "" do %>
            <button
              type="button"
              phx-click="clear"
              aria-label="Clear search"
              class="btn btn-ghost btn-xs absolute right-2 top-1/2 -translate-y-1/2"
            >
              <span aria-hidden="true">×</span>
            </button>
          <% end %>
        </div>
      </form>

      <div data-test="results" class="space-y-1">
        <%= if @query != "" do %>
          <%= if @results == [] do %>
            <p class="text-sm opacity-70">No matches yet — keep typing, or this tag may be new.</p>
          <% else %>
            <%= for result <- @results do %>
              <div class="card bg-base-200 p-3 flex row items-center justify-between gap-2">
                <div>
                  <div class="font-semibold">
                    {if result.prefix, do: "#{result.prefix} | "}{result.gamer_tag}
                  </div>
                  <div class="text-xs opacity-70">ID #{result.user_id}</div>
                </div>
                <div class="text-right">
                  <span class="badge badge-primary">Elo {trunc(result.elo)}</span>
                </div>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
