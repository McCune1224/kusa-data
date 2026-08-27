defmodule KusaDataWeb.AtlasLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the atlas map view with the canvas and title", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/atlas")

    assert html =~ "Atlas"
    assert html =~ ~s(id="atlas-canvas")
  end

  test "renders the player network view without crashing", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/atlas/player/123")

    assert html =~ ~s(id="atlas-canvas")
  end

  test "static render of the map route shows the canvas", %{conn: conn} do
    conn = get(conn, ~p"/atlas")
    html = html_response(conn, 200)

    assert html =~ "Atlas"
    assert html =~ ~s(id="atlas-canvas")
  end
end
