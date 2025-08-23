defmodule MiniappWeb.Router do
  use MiniappWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MiniappWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers,%{
      "content-security-policy" => "default-src 'self'; img-src 'self' data: https:; script-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors *"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MiniappWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", MiniappWeb do
    pipe_through :api

    get "/dice", DiceController, :roll
  end

  # Other scopes may use custom stacks.
  # scope "/api", MiniappWeb do
  #   pipe_through :api
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:miniapp, :dev_routes) do

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
