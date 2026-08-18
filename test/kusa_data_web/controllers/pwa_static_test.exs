defmodule KusaDataWeb.PWAStaticTest do
  use KusaDataWeb.ConnCase, async: false

  test "manifest and service worker are served as static assets", %{conn: conn} do
    manifest = conn |> get("/manifest.webmanifest") |> response(200)
    assert manifest =~ "KusaData"
    assert manifest =~ "\"display\": \"standalone\""

    worker_conn = get(build_conn(), "/service-worker.js")
    assert response(worker_conn, 200) =~ "CACHE_NAME"
  end
end
