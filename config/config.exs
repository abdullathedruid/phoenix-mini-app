# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :miniapp,
  ecto_repos: [Miniapp.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :miniapp, MiniappWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MiniappWeb.ErrorHTML, json: MiniappWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Miniapp.PubSub,
  live_view: [signing_salt: "mBBdxrnG"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :miniapp, Miniapp.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  miniapp: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=. --loader:.js=jsx --loader:.jsx=jsx --define:process.env.NODE_ENV=\"development\" --define:process.env=\"{}\"),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  miniapp: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :file, :line, :span_id, :trace_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# OpenTelemetry
config :opentelemetry,
  resource: %{service: %{name: "miniapp"}}

# PromEx
config :miniapp, Miniapp.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
