defmodule PgQueuetopia.TestRepo.Migrations.CreateQueuetopiaTables do
  use Ecto.Migration

  def up do
    PgQueuetopia.Migrations.V1.up()
  end

  def down do
    PgQueuetopia.Migrations.V1.down()
  end
end
