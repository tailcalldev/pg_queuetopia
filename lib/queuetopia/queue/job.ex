defmodule PgQueuetopia.Queue.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset, only: [cast: 3, put_change: 3, validate_number: 3, validate_required: 2]

  @type t :: %__MODULE__{
          action: binary,
          attempts: integer,
          attempted_at: DateTime.t() | nil,
          attempted_by: binary,
          done_at: DateTime.t() | nil,
          error: binary | nil,
          id: integer,
          inserted_at: DateTime.t(),
          max_attempts: integer,
          max_backoff: integer,
          next_attempt_at: DateTime.t() | nil,
          params: map,
          performer: binary,
          queue: binary,
          scheduled_at: DateTime.t(),
          scope: binary,
          timeout: integer,
          updated_at: DateTime.t()
        }
  @type option ::
          {:timeout, non_neg_integer()}
          | {:max_backoff, non_neg_integer()}
          | {:max_attempts, non_neg_integer()}

  @default_timeout 60 * 1_000
  @default_max_backoff 24 * 3600 * 1_000
  @default_max_attempts 20

  schema "pg_queuetopia_jobs" do
    field(:scope, :string)
    field(:queue, :string)
    field(:performer, :string)
    field(:action, :string)
    field(:params, :map)
    field(:timeout, :integer, default: @default_timeout)
    field(:max_backoff, :integer, default: @default_max_backoff)
    field(:max_attempts, :integer, default: @default_max_attempts)

    field(:scheduled_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:attempted_at, :utc_datetime)
    field(:attempted_by, :string)
    field(:next_attempt_at, :utc_datetime)
    field(:done_at, :utc_datetime)
    field(:error, :string, null: true)

    timestamps()
  end

  def default_timeout(), do: @default_timeout
  def default_max_backoff(), do: @default_max_backoff
  def default_max_attempts(), do: @default_max_attempts

  @spec create_changeset(map) :: Ecto.Changeset.t()
  def create_changeset(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :scope,
      :queue,
      :performer,
      :action,
      :params,
      :timeout,
      :max_backoff,
      :max_attempts,
      :scheduled_at
    ])
    |> validate_required([
      :scope,
      :queue,
      :performer,
      :action,
      :params,
      :timeout,
      :max_backoff,
      :max_attempts,
      :scheduled_at
    ])
    |> validate_number(:timeout, greater_than_or_equal_to: 0)
    |> validate_number(:max_backoff, greater_than_or_equal_to: 0)
    |> validate_number(:max_attempts, greater_than_or_equal_to: 0)
  end

  @spec failed_job_changeset(Job.t(), map) :: Ecto.Changeset.t()
  def failed_job_changeset(%__MODULE__{} = job, attrs) when is_map(attrs) do
    job
    |> cast(attrs, [:attempts, :attempted_at, :attempted_by, :next_attempt_at, :error])
    |> validate_required_attempt_attributes
    |> validate_required([:next_attempt_at, :error])
  end

  @spec succeeded_job_changeset(Job.t(), map) :: Ecto.Changeset.t()
  def succeeded_job_changeset(%__MODULE__{} = job, attrs) when is_map(attrs) do
    job
    |> cast(attrs, [:attempts, :attempted_at, :attempted_by, :done_at])
    |> validate_required_attempt_attributes
    |> validate_required([:done_at])
    |> put_change(:error, nil)
  end

  defp validate_required_attempt_attributes(changeset) do
    changeset
    |> validate_required([:attempts, :attempted_at, :attempted_by])
  end
end
