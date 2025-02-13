defmodule CursorDemoWeb.Router do
  use CursorDemoWeb, :router

  import CursorDemoWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CursorDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_user do
    plug :ensure_authenticated
  end

  # Public routes
  scope "/", CursorDemoWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live "/register", UserRegistrationLive
    post "/register", UserRegistrationController, :create
    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    get "/confirm/:token", UserRegistrationController, :confirm
  end

  # Protected routes
  scope "/", CursorDemoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/", LandingLive
    live "/posts/:id", PostDetailLive
    live "/settings", SettingsLive
    delete "/logout", UserSessionController, :delete
    live "/:username", UserDetailLive
    live "/:username/following", UserFollowingLive
    live "/:username/followers", UserFollowersLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", CursorDemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:cursor_demo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CursorDemoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
