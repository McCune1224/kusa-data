defmodule KusaData.Watches do
  @moduledoc """
  Durable watches, snapshot change detection, notifications, and delivery state.

  A watch's first poll establishes its baseline. Later polls compare a stable
  JSON snapshot and create one notification per changed snapshot using the
  database unique `dedup_key` constraint, so retries and restarts are safe.
  """

  import Ecto.Query, warn: false

  alias KusaData.Events
  alias KusaData.Players
  alias KusaData.Repo
  alias KusaData.Tournaments
  alias KusaData.Watches.Notification
  alias KusaData.Watches.Watch
  alias KusaData.Watches.Delivery

  @default_interval 15 * 60

  @doc "Creates or returns the existing user-owned watch."
  def watch(user, kind, target_id, prefs \\ %{}) do
    attrs = %{
      user_id: user.id,
      kind: normalize_kind(kind),
      target_id: to_string(target_id),
      prefs: prefs
    }

    case Repo.get_by(Watch, user_id: user.id, kind: attrs.kind, target_id: attrs.target_id) do
      %Watch{} = existing -> {:ok, existing}
      nil -> %Watch{} |> Watch.changeset(attrs) |> Repo.insert()
    end
  end

  @doc "Removes a watch owned by the user."
  def unwatch(user, kind, target_id) do
    case Repo.get_by(Watch,
           user_id: user.id,
           kind: normalize_kind(kind),
           target_id: to_string(target_id)
         ) do
      nil ->
        :ok

      watch ->
        Repo.delete(watch)
        |> case do
          {:ok, _} -> :ok
          error -> error
        end
    end
  end

  @doc "Lists a user's watches, newest first."
  def for_user(user) do
    Repo.all(from(w in Watch, where: w.user_id == ^user.id, order_by: [desc: w.created_at]))
  end

  @doc "Checks whether a user watches a target."
  def watched?(user, kind, target_id) do
    kind = normalize_kind(kind)
    target_id = to_string(target_id)

    Repo.exists?(
      from(w in Watch,
        where: w.user_id == ^user.id and w.kind == ^kind and w.target_id == ^target_id
      )
    )
  end

  @doc "Updates preferences for one owned watch."
  def update_prefs(user, watch_id, prefs) when is_map(prefs) do
    case Repo.get_by(Watch, id: watch_id, user_id: user.id) do
      nil -> {:error, :not_found}
      watch -> watch |> Watch.changeset(%{prefs: prefs}) |> Repo.update()
    end
  end

  @doc "Unread notifications for a user."
  def notifications(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from(n in Notification,
        where: n.user_id == ^user.id,
        order_by: [desc: n.created_at],
        limit: ^limit
      )
    )
  end

  @doc "Unread count for a user."
  def unread_count(user) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user.id and is_nil(n.read_at)),
      :count,
      :id
    )
  end

  @doc "Marks one notification read only when it belongs to the user."
  def mark_read(user, notification_id) do
    case Repo.get_by(Notification, id: notification_id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification |> Ecto.Changeset.change(read_at: DateTime.utc_now()) |> Repo.update()
    end
  end

  @doc "Marks all notifications read for a user."
  def mark_all_read(user) do
    now = DateTime.utc_now()

    Repo.update_all(from(n in Notification, where: n.user_id == ^user.id and is_nil(n.read_at)),
      set: [read_at: now]
    )

    :ok
  end

  @doc "Returns watches whose polling interval has elapsed."
  def due_watches(now \\ DateTime.utc_now(), limit \\ 25) do
    cutoff = DateTime.add(now, -@default_interval, :second)

    Repo.all(
      from(w in Watch,
        where: is_nil(w.last_checked_at) or w.last_checked_at <= ^cutoff,
        order_by: [asc: w.last_checked_at, asc: w.id],
        limit: ^limit
      )
    )
  end

  @doc "Attempts configured external delivery for pending notifications."
  def deliver_pending(limit \\ 25) do
    pending =
      Repo.all(
        from(n in Notification,
          join: u in assoc(n, :user),
          left_join: w in assoc(n, :watch),
          where: n.delivery_status in ["pending", "failed"],
          order_by: [asc: n.created_at],
          limit: ^limit,
          preload: [user: u, watch: w]
        )
      )

    Enum.map(pending, fn notification ->
      prefs = (notification.watch && notification.watch.prefs) || %{}

      case Delivery.deliver(notification, notification.user, prefs) do
        {:ok, :disabled} ->
          {:ok, notification}

        {:ok, _results} ->
          mark_delivered(notification.id)

        {:error, reason} ->
          mark_delivery_failed(notification.id, reason)
      end
    end)
  end

  @doc "Polls one watch and persists its snapshot plus any change notification."
  def poll(watch_or_id) do
    watch = if is_integer(watch_or_id), do: Repo.get(Watch, watch_or_id), else: watch_or_id

    case watch do
      %Watch{} -> poll_watch(watch)
      nil -> {:error, :not_found}
    end
  end

  @doc "Polls all currently due watches."
  def poll_due(now \\ DateTime.utc_now(), limit \\ 25) do
    Enum.map(due_watches(now, limit), &poll/1)
  end

  @doc "Records a successful delivery attempt for a notification."
  def mark_delivered(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification
        |> Ecto.Changeset.change(delivered_at: DateTime.utc_now(), delivery_status: "delivered")
        |> Repo.update()
    end
  end

  @doc "Records a failed delivery attempt for retry/reporting."
  def mark_delivery_failed(notification_id, reason) do
    case Repo.get(Notification, notification_id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification
        |> Ecto.Changeset.change(
          delivery_status: "failed",
          delivery_attempts: notification.delivery_attempts + 1,
          last_error: inspect(reason)
        )
        |> Repo.update()
    end
  end

  defp poll_watch(%Watch{} = watch) do
    now = DateTime.utc_now()

    case fetch_snapshot(watch) do
      {:ok, snapshot} ->
        previous = watch.snapshot
        changes? = previous != nil and previous != snapshot

        result =
          Repo.transaction(fn ->
            {:ok, updated} =
              watch
              |> Watch.changeset(%{snapshot: snapshot, last_checked_at: now})
              |> Repo.update()

            notification =
              if changes? do
                create_change_notification(updated, previous, snapshot)
              else
                nil
              end

            {updated, notification}
          end)

        case result do
          {:ok, {updated, notification}} -> {:ok, updated, notification}
          error -> error
        end

      {:error, reason} ->
        _ = Watch.changeset(watch, %{last_checked_at: now}) |> Repo.update()
        {:error, reason}
    end
  end

  defp create_change_notification(watch, previous, snapshot) do
    version = snapshot_version(snapshot)
    dedup_key = "watch:#{watch.id}:#{version}"

    attrs = %{
      user_id: watch.user_id,
      watch_id: watch.id,
      type: "watch_changed",
      payload: %{
        "kind" => watch.kind,
        "target_id" => watch.target_id,
        "previous" => previous,
        "snapshot" => snapshot
      },
      dedup_key: dedup_key,
      delivery_status: "pending",
      delivery_attempts: 0
    }

    case %Notification{}
         |> Notification.changeset(attrs)
         |> Repo.insert(on_conflict: :nothing, conflict_target: :dedup_key) do
      {:ok, notification} ->
        notification

      {:error, %Ecto.Changeset{errors: [dedup_key: _]}} ->
        Repo.get_by(Notification, dedup_key: dedup_key)

      {:error, _} ->
        nil
    end
  end

  defp fetch_snapshot(%Watch{kind: "tournament", target_id: slug}) do
    case Tournaments.by_slug(slug) do
      {:ok, tournament, _} -> {:ok, tournament_snapshot(tournament)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_snapshot(%Watch{kind: "event", target_id: event_id}) do
    case Events.analytics(parse_id(event_id)) do
      {:ok, analytics, _} -> {:ok, analytics_snapshot(analytics)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_snapshot(%Watch{kind: "player", target_id: player_id}) do
    case Players.profile(parse_id(player_id)) do
      {:ok, profile, _} -> {:ok, profile}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_snapshot(_), do: {:error, :invalid_watch}

  defp tournament_snapshot(tournament) do
    %{
      "id" => tournament["id"],
      "slug" => tournament["slug"],
      "name" => tournament["name"],
      "startAt" => tournament["startAt"],
      "endAt" => tournament["endAt"],
      "events" =>
        (tournament["events"] || [])
        |> Enum.map(fn event ->
          %{"id" => event["id"], "state" => event["state"], "numEntrants" => event["numEntrants"]}
        end)
        |> Enum.sort_by(&to_string(&1["id"]))
    }
  end

  defp analytics_snapshot(%{"analysis" => analysis}) do
    %{
      "event" => get_in(analysis, ["context", "event_id"]),
      "entrant_count" => analysis["entrant_count"],
      "match_count" => analysis["match_count"],
      "standings" => analysis["entrants"]
    }
  end

  defp analytics_snapshot(analytics), do: analytics

  defp snapshot_version(snapshot),
    do:
      snapshot
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

  defp normalize_kind(kind) when is_atom(kind), do: Atom.to_string(kind)
  defp normalize_kind(kind) when is_binary(kind), do: kind
  defp normalize_kind(_), do: ""

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> 0
    end
  end
end
