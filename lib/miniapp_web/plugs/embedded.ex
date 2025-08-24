defmodule MiniappWeb.Plugs.Embedded do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; img-src 'self' data: https:; script-src 'self' 'sha256-ZSLtwbmogvdRQWylw6MDGKCK+VIz+hyMBvfpcdn8AQs='; style-src 'self' 'unsafe-inline'; frame-ancestors *"
    )
    |> delete_resp_header("x-frame-options")
  end
end
