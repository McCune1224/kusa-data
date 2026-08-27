defmodule KusaDataWeb.Router do
  use KusaDataWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KusaDataWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug KusaDataWeb.UserAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KusaDataWeb do
    pipe_through :browser

    get "/tournament/:slug/calendar.ics", CalendarController, :show

    live_session :public, on_mount: {KusaDataWeb.UserAuth, :mount_current_user} do
      live "/", HomeLive
      live "/regions", RegionLive
      live "/region/:country/:state", RegionLive
      live "/tournament/:slug", TournamentLive
      live "/event/:event", EventLive
      live "/player/:id", PlayerLive
      live "/player/:id/history", PlayerHistoryLive
      live "/player/:id/trend", PlayerTrendLive
      live "/player/:id/h2h", PlayerH2HLive
      live "/players/compare", CompareLive
      live "/rankings", RankingsLive
      live "/game/:game", GameLive
      live "/game/:game/player/:id", PlayerLive
      live "/atlas", AtlasLive
      live "/atlas/player/:id", AtlasLive
      live "/auth", AuthLive
    end

    live_session :user_required,
      on_mount: [
        {KusaDataWeb.UserAuth, :mount_current_user},
        {KusaDataWeb.UserAuth, :require_authenticated_user}
      ] do
      live "/your-tournaments", BookmarksLive
      live "/settings", PlayerSettingsLive
      live "/leagues", LeaguesLive
      live "/leagues/:id", LeagueLive
      live "/notifications", NotificationsLive
    end

    post "/log-in", UserSessionController, :create
    post "/register", UserRegistrationController, :create
    delete "/log-out", UserSessionController, :delete
  end

  scope "/feed", KusaDataWeb do
    pipe_through :api

    get "/upcoming.json", FeedController, :upcoming_json
    get "/recent.json", FeedController, :recent_json
    get "/upcoming.xml", FeedController, :upcoming_rss
    get "/recent.xml", FeedController, :recent_rss
  end

  scope "/api", KusaDataWeb.API do
    pipe_through :api

    get "/events/:event/seeds", EventController, :seeds
    get "/events/:event/results", EventController, :results
    get "/events/:event/sets", EventController, :sets
    get "/events/:event/analytics", EventController, :analytics
    get "/tournaments/:slug/export", TournamentController, :export
  end

  if Application.compile_env(:kusa_data, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KusaDataWeb.Telemetry
    end
  end
end
