defmodule KusaDataWeb.NotificationsLiveTest do
  use KusaDataWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  alias KusaData.Accounts
  alias KusaData.Watches

  test "shows notifications, active watches, and channel preferences", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "notifications@example.com",
        password: "correct horse battery"
      })

    {:ok, watch} = Watches.watch(user, :player, "100")
    {:ok, _session, token} = Accounts.create_session(user)
    conn = Phoenix.ConnTest.init_test_session(conn, %{user_token: token})

    {:ok, view, _html} = live(conn, "/notifications")
    assert has_element?(view, "#notifications")
    assert wait_has_element(view, "#watch-prefs-#{watch.id}")
  end
end
