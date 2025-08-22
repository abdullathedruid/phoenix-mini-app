defmodule MiniappWeb.PageController do
  use MiniappWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
