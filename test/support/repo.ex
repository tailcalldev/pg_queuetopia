defmodule PgQueuetopia.TestRepo do
  use Ecto.Repo,
    otp_app: :pg_queuetopia,
    adapter: Ecto.Adapters.Postgres
end
