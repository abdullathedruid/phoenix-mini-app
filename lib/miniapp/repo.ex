defmodule Miniapp.Repo do
  use Ecto.Repo,
    otp_app: :miniapp,
    adapter: Ecto.Adapters.Postgres
end
