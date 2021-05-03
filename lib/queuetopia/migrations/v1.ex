defmodule PgQueuetopia.Migrations.V1 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_locks_table()
    create_jobs_table()
  end

  def down do
    drop_locks_table()
    drop_jobs_table()
  end

  defp create_locks_table do
    create table(:pg_queuetopia_locks) do
      add(:scope, :string, null: false)
      add(:queue, :string, null: false)
      add(:locked_at, :utc_datetime, null: true)
      add(:locked_by_node, :string, null: true)
      add(:locked_until, :utc_datetime, null: true)

      timestamps()
    end

    create(
      unique_index(:pg_queuetopia_locks, [:scope, :queue],
        name: :pg_queuetopia_locks_scope_queue_index
      )
    )
  end

  defp drop_locks_table do
    drop(table(:pg_queuetopia_locks))
  end

  defp create_jobs_table() do
    create table(:pg_queuetopia_jobs) do
      add(:scope, :string, null: false)
      add(:queue, :string, null: false)
      add(:performer, :string, null: false)
      add(:action, :string, null: false)
      add(:params, :map, null: false)
      add(:timeout, :integer, null: false)
      add(:max_backoff, :integer, null: false)
      add(:max_attempts, :integer, null: false)

      add(:scheduled_at, :utc_datetime, null: false)
      add(:attempts, :integer, null: false, default: 0)
      add(:attempted_at, :utc_datetime, null: true)
      add(:attempted_by, :string, null: true)
      add(:next_attempt_at, :utc_datetime, null: true)
      add(:done_at, :utc_datetime, null: true)
      add(:error, :text, null: true)

      timestamps()
    end

    create(
      index(:pg_queuetopia_jobs, [:scope, :queue], name: :pg_queuetopia_jobs_scope_queue_index)
    )

    create(index(:pg_queuetopia_jobs, [:params], using: :gin))
    create(index(:pg_queuetopia_jobs, [:scheduled_at]))
    create(index(:pg_queuetopia_jobs, [:scheduled_at, :id]))
    create(index(:pg_queuetopia_jobs, [:done_at]))
  end

  defp drop_jobs_table do
    drop(table(:pg_queuetopia_jobs))
  end
end
