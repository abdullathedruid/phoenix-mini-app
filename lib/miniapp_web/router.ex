defmodule MiniappWeb.Router do
  use MiniappWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MiniappWeb.Layouts, :root}
    plug :protect_from_forgery
  end

  # https://elixirforum.com/t/how-to-embed-a-liveview-via-iframe/65066
  pipeline :embedded do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MiniappWeb.Layouts, :root}
    plug :protect_from_forgery
    plug MiniappWeb.Plugs.Embedded
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MiniappWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/embed", MiniappWeb do
    pipe_through :embedded

    live_session :embedded, layout: {MiniappWeb.Layouts, :root} do
      live "/wallet", WalletLive, :home
    end
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
