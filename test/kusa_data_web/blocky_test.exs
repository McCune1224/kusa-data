defmodule KusaDataWeb.BlockyTest do
  use KusaDataWeb.ConnCase, async: false
  use KusaData.Test.Doubles
  import Phoenix.LiveViewTest

  @forbidden ["rounded-card", "rounded-pill", "rounded-full", "rounded-[10px]"]

  test "no forbidden rounded classes remain in components and live views" do
    files =
      Path.wildcard("lib/kusa_data_web/**/*.ex") ++
        Path.wildcard("lib/kusa_data_web/**/*.heex") ++
        Path.wildcard("assets/css/*.css")

    violations =
      for file <- files,
          content = File.read!(file),
          token <- @forbidden,
          String.contains?(content, token),
          do: "#{file}: contains #{token}"

    assert violations == [], "blocky invariant violated:\n" <> Enum.join(violations, "\n")
  end

  test "radius tokens are zero" do
    css = File.read!("assets/css/app.css")
    assert css =~ "--radius-card: 0px"
    assert css =~ "--radius-pill: 0px"
  end

  test "every public page renders with blocky shell" do
    routes = [
      "/",
      "/regions",
      "/region/US/CA",
      "/tournament/genesis-2026",
      "/event/123",
      "/player/123",
      "/atlas",
      "/auth",
      "/players/compare",
      "/game/melee",
      "/rankings"
    ]

    for route <- routes do
      {:ok, _view, html} = live(build_conn(), route)
      assert html =~ "KusaData", "route #{route} missing shell"
      refute html =~ "rounded-card", "route #{route} leaked rounded-card"
      refute html =~ "rounded-pill", "route #{route} leaked rounded-pill"
      refute html =~ "rounded-full", "route #{route} leaked rounded-full"
    end
  end

  test "core components render square primitives" do
    {:ok, view, _html} = live(build_conn(), "/")
    html = render(view)
    assert html =~ "rounded-none"
  end
end
