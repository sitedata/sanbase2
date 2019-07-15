import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :sanbase, Sanbase, url: {:system, "SANBASE_URL", "https://sanbase-low-stage.santiment.net"}

config :sanbase, SanbaseWeb.Endpoint,
  http: [port: 4000],
  url: [host: "0.0.0.0"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# command from your terminal:
#
#     openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" -keyout priv/server.key -out priv/server.pem
#
# The `http:` config above can be replaced with:
#
#     https: [port: 4000, keyfile: "priv/server.key", certfile: "priv/server.pem"],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

config :logger, level: :debug
# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$time][$level][$metadata] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :sanbase, Sanbase.ApiCallDataExporter,
  supervisor: Sanbase.InMemoryKafka.Supervisor,
  producer: Sanbase.InMemoryKafka.Producer

# Configure your database
config :sanbase, Sanbase.Repo,
  username: "postgres",
  password: "postgres",
  database: "sanbase_dev",
  hostname: "localhost"

# Configure your database
config :sanbase, Sanbase.TimescaleRepo,
  username: "postgres",
  password: "postgres",
  database: "sanbase_timescale_dev",
  hostname: "localhost",
  pool_size: 3

# Clickhousex does not support `:system` tuples. The configuration is done
# by defining defining `:url` in the ClickhouseRepo `init` function.
config :sanbase, Sanbase.ClickhouseRepo,
  adapter: ClickhouseEcto,
  loggers: [Ecto.LogEntry, Sanbase.Prometheus.EctoInstrumenter],
  hostname: "clickhouse",
  port: 8123,
  database: "default",
  username: "default",
  password: "",
  pool_timeout: 60_000,
  timeout: 60_000,
  pool_size: {:system, "CLICKHOUSE_POOL_SIZE", "3"}

config :sanbase, Sanbase.Timescaledb, blockchain_schema: nil

config :ex_admin,
  basic_auth: [
    username: "admin",
    password: "admin",
    realm: "Admin Area"
  ]

config :sanbase, Sanbase.ExternalServices.Etherscan.RateLimiter,
  scale: 1000,
  limit: 5,
  time_between_requests: 250

config :sanbase, SanbaseWeb.Graphql.ContextPlug,
  basic_auth_username: "admin",
  basic_auth_password: "admin"

config :arc,
  storage: Arc.Storage.Local,
  storage_dir: "/tmp/sanbase/filestore/"

if File.exists?("config/dev.secret.exs") do
  import_config "dev.secret.exs"
end
