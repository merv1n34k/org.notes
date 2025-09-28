defmodule OrgNotesWeb.Router do
  use OrgNotesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OrgNotesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :authenticated do
    plug OrgNotesWeb.Auth.RequireAuth
  end

  pipeline :super_admin do
    plug OrgNotesWeb.Auth.RequireSuperAdmin
  end

  # Public routes
  scope "/", OrgNotesWeb do
    pipe_through :browser

    live "/", WelcomeLive, :index
    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  # Authenticated routes - Using live_session for proper current_scope
  scope "/", OrgNotesWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{OrgNotesWeb.Auth.AuthHook, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index
    end
  end

  # Super admin routes - Using live_session
  scope "/admin", OrgNotesWeb do
    pipe_through :browser

    live_session :super_admin,
      on_mount: [{OrgNotesWeb.Auth.AuthHook, :ensure_authenticated}] do
      live "/server", ServerManagementLive, :index
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:org_notes, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OrgNotesWeb.Telemetry
    end
  end
end
