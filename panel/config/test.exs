import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :e_any_panel, EAnyPanel.Repo,
  username: "postgres",
  password: System.get_env("DB_PASSWORD"),
  hostname: System.get_env("DB_HOSTNAME", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  database: "e_any_panel_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :e_any_panel, EAnyPanelWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "g0m9H6VPQm+cE1FA4ZLRkSOQEjKJelumL/LK/oylbab1Ie3umzmJO5LCbZqh3BQr",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# NpmClient disabled in test (no token at runtime, avoids compile-env mismatch)
config :e_any_panel, EAnyPanel.NpmClient, base_url: "http://core-nginx:81", token: "test-token"
