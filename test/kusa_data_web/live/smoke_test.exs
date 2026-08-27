defmodule KusaDataWeb.LiveSmokeTest do
  @moduledoc """
  Smoke test: every public LiveView must mount and render the app shell
  without raising. Data comes from the fake GraphQL transport, which returns
  no fixtures here, so pages fall back to their empty/error states — the point
  is that they render at all.
  """
  use KusaDataWeb.ConnCase, async: false
  use KusaData.Test.Doubles
  import Phoenix.LiveViewTest

  test "home renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "KusaData"
  end

  test "regions index renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/regions")
    assert html =~ "KusaData"
  end

  test "region detail renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/region/US/CA")
    assert html =~ "KusaData"
  end

  test "tournament detail renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/tournament/genesis-2026")
    assert html =~ "KusaData"
  end

  test "event detail renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/event/123")
    assert html =~ "KusaData"
  end

  test "player renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/player/123")
    assert html =~ "KusaData"
  end

  test "player history renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/player/123/history")
    assert html =~ "KusaData"
  end

  test "player trend renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/player/123/trend")
    assert html =~ "KusaData"
  end

  test "player h2h renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/player/123/h2h")
    assert html =~ "KusaData"
  end

  test "rankings renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/rankings")
    assert html =~ "KusaData"
  end

  test "game renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/game/melee")
    assert html =~ "KusaData"
  end

  test "compare renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/players/compare")
    assert html =~ "KusaData"
  end

  test "atlas renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/atlas")
    assert html =~ "KusaData"
  end

  test "auth renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/auth")
    assert html =~ "KusaData"
  end
end
