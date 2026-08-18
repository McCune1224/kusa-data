defmodule KusaDataWeb.AccountLiveTest do
  use KusaDataWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias KusaData.Accounts

  defp signed_in_conn(conn) do
    {:ok, user} =
      Accounts.register_user(%{email: "live@example.com", password: "correct horse battery"})

    {:ok, _session, token} = Accounts.create_session(user)
    Phoenix.ConnTest.init_test_session(conn, %{user_token: token})
  end

  test "anonymous account-owned routes redirect to auth", %{conn: conn} do
    assert {:error, {:redirect, %{to: to}}} = live(conn, "/settings")
    assert to =~ "/auth?mode=login"
  end

  test "auth page exposes normal controller POST forms", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/auth?mode=login")
    assert has_element?(view, "#login-form[action='/log-in']")
    assert has_element?(view, "#login-form input[name='return_to']")

    assert {:ok, _view, _html} = live(conn, "/auth?mode=register")
  end

  test "signed-in users can open saved, settings, and league surfaces", %{conn: conn} do
    conn = signed_in_conn(conn)
    assert {:ok, bookmarks, _html} = live(conn, "/your-tournaments")
    assert has_element?(bookmarks, "#bookmarks")

    assert {:ok, settings, _html} = live(conn, "/settings")
    assert has_element?(settings, "#player-search-form")
    assert has_element?(settings, "#alias-form")

    assert {:ok, leagues, _html} = live(conn, "/leagues")
    assert has_element?(leagues, "#league-form")
  end
end
