defmodule Miniapp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryLoggerMetadata.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:miniapp, :repo])

    children = [
      Miniapp.PromEx,
      MiniappWeb.Telemetry,
      Miniapp.Repo,
      {DNSCluster, query: Application.get_env(:miniapp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Miniapp.PubSub},
      # Start a worker by calling: Miniapp.Worker.start_link(arg)
      # {Miniapp.Worker, arg},
      # Start to serve requests, typically the last entry
      MiniappWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Miniapp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MiniappWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
