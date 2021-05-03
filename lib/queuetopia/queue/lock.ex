defmodule PgQueuetopia.Queue.Lock do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset, only: [cast: 3, unique_constraint: 3, validate_required: 2]

  @type t :: %__MODULE__{
          id: integer,
          inserted_at: DateTime.t(),
          locked_at: DateTime.t(),
          locked_by_node: binary,
          locked_until: DateTime.t(),
          queue: binary,
          scope: binary,
          updated_at: DateTime.t()
        }

  schema "pg_queuetopia_locks" do
    field(:scope, :string)
    field(:queue, :string)
    field(:locked_at, :utc_datetime)
    field(:locked_by_node, :string)
    field(:locked_until, :utc_datetime)

    timestamps()
  end

  @spec changeset(Lock.t(), map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = lock, attrs) when is_map(attrs) do
    lock
    |> cast(attrs, [:scope, :queue, :locked_at, :locked_by_node, :locked_until])
    |> validate_required([:scope, :queue, :locked_at, :locked_by_node, :locked_until])
    |> unique_constraint(:queue, name: :pg_queuetopia_locks_scope_queue_index)
  end
end
