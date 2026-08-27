defmodule KusaDataWeb.NotificationsLive do
  @moduledoc """
  In-app notifications for the signed-in user, with per-item and bulk read
  actions backed by `KusaData.Watches`.
  """
  use KusaDataWeb, :live_view

  alias KusaData.Watches
  alias KusaData.Watches.Notification
  alias KusaDataWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, notifications: [], has_unread: false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load_notifications(socket)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_user
    :ok = Watches.mark_all_read(user)
    {:noreply, load_notifications(socket)}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Integer.parse(id) do
      {parsed_id, ""} ->
        case Watches.mark_read(user, parsed_id) do
          {:ok, _notification} -> {:noreply, load_notifications(socket)}
          {:error, _reason} -> {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp load_notifications(socket) do
    user = socket.assigns.current_user
    notifications = Watches.notifications(user)
    has_unread = Enum.any?(notifications, &is_nil(&1.read_at))
    assign(socket, notifications: notifications, has_unread: has_unread)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={:tournaments}>
      <div id="notifications-live" class="mx-auto max-w-2xl">
        <div class="flex items-center justify-between gap-4">
          <h1 class="font-display text-2xl font-semibold text-ink">Notifications</h1>
          <%= if @has_unread do %>
            <.button variant="secondary" size="sm" phx-click="mark_all_read">Mark all read</.button>
          <% end %>
        </div>

        <%= if Enum.empty?(@notifications) do %>
          <.empty
            class="mt-8"
            icon="hero-bell"
            title="No notifications"
            description="You're all caught up — we'll let you know when a watched tournament, event, or player changes."
          />
        <% else %>
          <ul class="mt-6 space-y-3">
            <%= for n <- @notifications do %>
              <li class="flex items-start justify-between gap-4 rounded-card border border-line bg-surface px-5 py-4 transition-colors hover:border-accent-line">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <h3 class="truncate font-semibold text-ink">{notification_title(n)}</h3>
                    <%= if is_nil(n.read_at) do %>
                      <.badge variant="accent">New</.badge>
                    <% end %>
                  </div>
                  <p class="mt-1 text-sm text-muted">{notification_body(n)}</p>
                  <p class="mt-2 text-xs text-faint">
                    {Format.relative_time(DateTime.to_unix(n.created_at))}
                  </p>
                </div>
                <%= if is_nil(n.read_at) do %>
                  <.button variant="ghost" size="sm" phx-click="mark_read" phx-value-id={n.id}>
                    Mark read
                  </.button>
                <% end %>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp notification_title(%Notification{} = notification) do
    payload = notification.payload || %{}
    kind = payload["kind"]
    name = payload["snapshot"]["name"]

    cond do
      name -> "#{human_kind(kind)} · #{name}"
      kind -> "#{human_kind(kind)} update"
      true -> "Notification"
    end
  end

  defp notification_body(%Notification{} = notification) do
    kind = (notification.payload || %{})["kind"]
    "Your #{String.downcase(human_kind(kind))} watch detected a change."
  end

  defp human_kind("tournament"), do: "Tournament"
  defp human_kind("event"), do: "Event"
  defp human_kind("player"), do: "Player"
  defp human_kind(_), do: "Watch"
end
