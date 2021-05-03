import Config

if(Mix.env() == :test) do
  config :logger, level: System.get_env("EX_LOG_LEVEL", "warn") |> String.to_atom()

  config :pg_queuetopia, ecto_repos: [PgQueuetopia.TestRepo]

  config :pg_queuetopia, PgQueuetopia.TestRepo,
    url: System.get_env("PG_QUEUETOPIA__DATABASE_TEST_URL"),
    pool: Ecto.Adapters.SQL.Sandbox
end
