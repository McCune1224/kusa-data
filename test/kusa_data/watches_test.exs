defmodule KusaData.WatchesTest do
  use KusaData.DataCase, async: false
  use KusaData.Test.Doubles

  alias KusaData.Accounts
  alias KusaData.Cache
  alias KusaData.Repo
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures
  alias KusaData.Watches
  alias KusaData.Watches.Notification
  alias KusaData.Watches.Watch

  defp user(email \\ "watcher@example.com") do
    {:ok, user} = Accounts.register_user(%{email: email, password: "correct horse battery"})
    user
  end

  test "watch is idempotent and owner scoped" do
    user = user()
    assert {:ok, first} = Watches.watch(user, :tournament, "tournament/example")

    assert {:ok, second} =
             Watches.watch(user, "tournament", "tournament/example", %{"email" => false})

    assert first.id == second.id
    assert Watches.watched?(user, :tournament, "tournament/example")
    assert [watch] = Watches.for_user(user)
    assert watch.prefs == %{}
    assert :ok = Watches.unwatch(user, :tournament, "tournament/example")
    refute Watches.watched?(user, :tournament, "tournament/example")
  end

  test "poll establishes a baseline, then creates one notification per snapshot" do
    user = user()

    tournament =
      Fixtures.tournament(1, %{
        "slug" => "tournament/example",
        "events" => [%{"id" => 100_001, "state" => 2, "numEntrants" => 32}]
      })

    changed = put_in(tournament, ["events", Access.at(0), "state"], 3)

    FakeTransport.put(:query, "TournamentDetail", fn
      1 -> Fixtures.tournament_detail_response(tournament)
      _ -> Fixtures.tournament_detail_response(changed)
    end)

    assert {:ok, watch} = Watches.watch(user, :tournament, "tournament/example")
    assert {:ok, _updated, nil} = Watches.poll(watch)
    Cache.delete("tournament:tournament/example")
    watch = Repo.get!(Watch, watch.id)
    assert {:ok, _updated, %Notification{}} = Watches.poll(watch)
    Cache.delete("tournament:tournament/example")
    watch = Repo.get!(Watch, watch.id)
    assert {:ok, _updated, nil} = Watches.poll(watch)
    assert Repo.aggregate(Notification, :count, :id) == 1
  end

  test "read and delivery state transitions are owner-safe" do
    user = user()
    other = user("other@example.com")
    assert {:ok, watch} = Watches.watch(user, :player, "100")

    notification =
      %Notification{}
      |> Notification.changeset(%{
        user_id: user.id,
        watch_id: watch.id,
        type: "watch_changed",
        dedup_key: "manual-1"
      })
      |> Repo.insert!()

    assert {:error, :not_found} = Watches.mark_read(other, notification.id)
    assert {:ok, _} = Watches.mark_read(user, notification.id)
    assert {:ok, delivered} = Watches.mark_delivered(notification.id)
    assert delivered.delivery_status == "delivered"
  end

  test "delivery adapters stay disabled without explicit channel config" do
    user = user("delivery@example.com")
    notification = %Notification{payload: %{"kind" => "player", "target_id" => "100"}}

    assert {:error, :disabled} = KusaData.Watches.Delivery.Email.deliver(notification, user, %{})

    assert {:error, :disabled} =
             KusaData.Watches.Delivery.Telegram.deliver(notification, user, %{})

    assert {:error, :disabled} =
             KusaData.Watches.Delivery.Discord.deliver(notification, user, %{})

    assert {:ok, :disabled} =
             KusaData.Watches.Delivery.deliver(notification, user, %{"channels" => []})
  end
end
