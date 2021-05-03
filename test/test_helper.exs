{:ok, _pid} = PgQueuetopia.TestRepo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(PgQueuetopia.TestRepo, :manual)

ExUnit.start()
