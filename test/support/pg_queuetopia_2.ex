defmodule PgQueuetopia.TestPgQueuetopia_2 do
  use PgQueuetopia,
    otp_app: :pg_queuetopia,
    repo: PgQueuetopia.TestRepo,
    performer: PgQueuetopia.TestPerfomer
end
