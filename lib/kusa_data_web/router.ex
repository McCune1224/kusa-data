defmodule KusaDataWeb.Router do
  use KusaDataWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KusaDataWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KusaDataWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/tournament/:slug", TournamentLive
    live "/event/:event", EventLive
    live "/player/:id", PlayerLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", KusaDataWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:kusa_data, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KusaDataWeb.Telemetry
    end
  end
end
