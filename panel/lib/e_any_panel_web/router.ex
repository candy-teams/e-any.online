defmodule EAnyPanelWeb.Router do
  use EAnyPanelWeb, :router

  import EAnyPanelWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EAnyPanelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth_required do
    plug :fetch_current_user
    plug :require_authenticated_user
  end

  pipeline :auth_redirect do
    plug :fetch_current_user
    plug :redirect_if_user_is_authenticated
  end

  scope "/", EAnyPanelWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Session mutation happens in a controller (websockets cannot write the Plug
  # session). The LiveView posts here with a signed token.
  scope "/", EAnyPanelWeb do
    pipe_through :browser

    get "/session/create", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  # Public, redirect-if-authenticated routes (login screen).
  scope "/", EAnyPanelWeb do
    pipe_through [:browser, :auth_redirect]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{EAnyPanelWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/login", SessionLive, :new
      live "/login/totp", SessionLive, :totp
    end
  end

  # Authenticated, admin-only routes.
  scope "/", EAnyPanelWeb do
    pipe_through [:browser, :auth_required]

    live_session :require_authenticated_user,
      on_mount: [{EAnyPanelWeb.UserAuth, :require_authenticated_user}] do
      live "/admin", DashboardLive, :index
      live "/admin/dashboard", DashboardLive, :index
      live "/admin/infisical", InfisicalLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", EAnyPanelWeb do
  #   pipe_through :api
  # end
end
