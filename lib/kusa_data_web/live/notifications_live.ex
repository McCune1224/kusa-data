defmodule KusaDataWeb.NotificationsLive do
  use KusaDataWeb, :live_view

  alias KusaData.Tournaments
  alias KusaData.Watches

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(nav: :notifications, mode: :notifications, loading: true, watches: [], digest: nil)
     |> stream_configure(:notifications,
       dom_id: fn notification -> "notification-#{notification.id}" end
     )
     |> stream(:notifications, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    mode = if params["mode"] == "digest", do: :digest, else: :notifications
    watches = Watches.for_user(socket.assigns.current_user)

    if mode == :notifications do
      {:noreply,
       socket
       |> assign(mode: mode, loading: false, watches: watches, digest: nil)
       |> stream(:notifications, Watches.notifications(socket.assigns.current_user), reset: true)}
    else
      {:noreply, socket |> assign(mode: mode, loading: true, watches: watches) |> spawn_digest()}
    end
  end

  @impl true
  def handle_info({:notifications_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    {:noreply,
     socket
     |> assign(loading: false, load_ref: nil, digest: result)
     |> stream(:notifications, [], reset: true)}
  end

  def handle_info({:notifications_loaded, _ref, _result}, socket), do: {:noreply, socket}

  defp spawn_digest(socket) do
    ref = make_ref()
    parent = self()

    Task.start(fn -> send(parent, {:notifications_loaded, ref, build_digest()}) end)
    assign(socket, load_ref: ref)
  end

  @impl true
  def handle_event("mark-read", %{"id" => id}, socket) do
    _ = Watches.mark_read(socket.assigns.current_user, parse_id(id))
    {:noreply, push_patch(socket, to: current_path(socket.assigns.mode))}
  end

  @impl true
  def handle_event("mark-all-read", _params, socket) do
    :ok = Watches.mark_all_read(socket.assigns.current_user)
    {:noreply, push_patch(socket, to: "/notifications")}
  end

  @impl true
  def handle_event("save-prefs", %{"watch_id" => watch_id} = params, socket) do
    channels = Map.get(params, "channels", [])

    _ =
      Watches.update_prefs(socket.assigns.current_user, parse_id(watch_id), %{
        "channels" => channels
      })

    {:noreply, push_patch(socket, to: current_path(socket.assigns.mode))}
  end

  @impl true
  def handle_event("remove-watch", %{"kind" => kind, "target_id" => target_id}, socket) do
    :ok = Watches.unwatch(socket.assigns.current_user, kind, target_id)
    {:noreply, push_patch(socket, to: current_path(socket.assigns.mode))}
  end

  defp build_digest do
    today = Date.utc_today()
    monday = Date.add(today, -(Date.day_of_week(today) - 1))
    from = DateTime.new!(monday, ~T[00:00:00], "Etc/UTC") |> DateTime.to_iso8601()
    to = DateTime.utc_now() |> DateTime.to_iso8601()

    tournaments =
      case Tournaments.browse(%{
             mode: :past,
             from: from,
             to: to,
             results_only: true,
             games: ["melee"]
           }) do
        {:ok, result, _} -> result["tournaments"] || []
        _ -> []
      end

    %{
      "week_start" => Date.to_iso8601(monday),
      "tournaments" => Enum.sort_by(tournaments, &(-to_int(&1["numEntrants"])))
    }
  end

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_binary(value), do: String.to_integer(value)
  defp to_int(_), do: 0

  defp current_path(:digest), do: "/notifications?mode=digest"
  defp current_path(_), do: "/notifications"

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} nav={@nav} current_user={@current_user}>
      <div>
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">Signal desk</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight text-stone-50">
              {if @mode == :digest, do: "This week in Melee", else: "Notifications"}
            </h1>
            <p class="mt-1 text-sm text-stone-400">
              {if @mode == :digest,
                do: "A deterministic weekly view of finished events and the biggest brackets.",
                else: "Changes from the tournaments, events, and players you watch."}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <.link patch="/notifications" class={tab_class(@mode == :notifications)}>Alerts</.link>
            <.link patch="/notifications?mode=digest" class={tab_class(@mode == :digest)}>Digest</.link>
          </div>
        </div>

        <%= if @mode == :notifications do %>
          <div class="mt-8 flex items-center justify-between gap-3">
            <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              Recent changes
            </h2>
            <.btn variant="ghost" size="sm" phx-click="mark-all-read">Mark all read</.btn>
          </div>
          <div id="notifications" phx-update="stream" class="mt-3 space-y-2">
            <div
              id="notifications-empty"
              class="hidden only:block rounded-xl border border-stone-800 bg-stone-900/30 p-6 text-sm text-stone-500"
            >
              No changes yet. Add a watch on a tournament, event, or player.
            </div>
            <div
              :for={{id, notification} <- @streams.notifications}
              id={id}
              class={notification_class(notification)}
            >
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0">
                  <p class="text-sm font-medium text-stone-200">{notification_title(notification)}</p>
                  <p class="mt-1 truncate font-mono text-xs text-stone-500">
                    {notification.payload["kind"]} · {notification.payload["target_id"]}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="mark-read"
                  phx-value-id={notification.id}
                  class="shrink-0 text-xs text-stone-500 hover:text-stone-100"
                >
                  Mark read
                </button>
              </div>
            </div>
          </div>

          <div class="mt-10">
            <h2 class="text-xs font-medium uppercase tracking-[0.18em] text-stone-400">
              Active watches
            </h2>
            <div class="mt-3 space-y-2">
              <div
                :for={watch <- @watches}
                class="rounded-xl border border-stone-800 bg-stone-900/30 px-4 py-3"
              >
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <span class="text-xs font-semibold uppercase tracking-[0.16em] text-lime-300">{watch.kind}</span>
                    <span class="ml-3 font-mono text-sm text-stone-300">{watch.target_id}</span>
                  </div>
                  <button
                    type="button"
                    phx-click="remove-watch"
                    phx-value-kind={watch.kind}
                    phx-value-target_id={watch.target_id}
                    class="text-xs text-stone-500 hover:text-rose-300"
                  >Remove</button>
                </div>
                <form
                  id={"watch-prefs-#{watch.id}"}
                  phx-submit="save-prefs"
                  phx-value-watch_id={watch.id}
                  class="mt-3 flex flex-wrap items-center gap-3"
                >
                  <label
                    :for={channel <- ~w(email telegram discord)}
                    class="inline-flex items-center gap-1.5 text-xs text-stone-400"
                  >
                    <input
                      type="checkbox"
                      name="channels[]"
                      value={channel}
                      checked={channel in (watch.prefs["channels"] || [])}
                    />
                    {channel}
                  </label>
                  <button
                    type="submit"
                    class="ml-auto text-xs font-semibold text-lime-300 hover:text-lime-200"
                  >Save preferences</button>
                </form>
              </div>
              <div :if={@watches == []} class="text-sm text-stone-600">No active watches.</div>
            </div>
          </div>
        <% else %>
          <div class="mt-8 rounded-xl border border-stone-800 bg-stone-900/30 p-5">
            <p class="font-mono text-xs uppercase tracking-[0.16em] text-lime-300">
              Week of {@digest && @digest["week_start"]}
            </p>
            <div class="mt-5 space-y-2">
              <div
                :for={tournament <- (@digest && @digest["tournaments"]) || []}
                class="flex items-center justify-between gap-4 rounded-md px-3 py-3 hover:bg-stone-900/70"
              >
                <.link
                  navigate={~p"/tournament/#{tournament["slug"]}"}
                  class="truncate text-[15px] text-stone-200 hover:text-lime-300"
                >
                  {tournament["name"]}
                </.link>
                <span class="shrink-0 font-mono text-xs text-stone-500">{tournament["numEntrants"] ||
                  0} entrants</span>
              </div>
              <div :if={@digest && @digest["tournaments"] == []} class="text-sm text-stone-600">
                No completed events this week.
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp tab_class(true),
    do: "rounded-none bg-lime-400 px-3 py-1.5 text-xs font-semibold text-stone-950"

  defp tab_class(false),
    do:
      "rounded-none border border-stone-700/70 px-3 py-1.5 text-xs text-stone-400 hover:text-stone-100"

  defp notification_class(%{read_at: nil}),
    do: "rounded-xl border border-lime-400/30 bg-lime-400/5 p-4"

  defp notification_class(_), do: "rounded-xl border border-stone-800 bg-stone-900/30 p-4"

  defp notification_title(notification) do
    case notification.type do
      "watch_changed" -> "A watched #{notification.payload["kind"]} changed"
      type -> String.replace(type, "_", " ")
    end
  end
end
