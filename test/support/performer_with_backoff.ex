defmodule PgQueuetopia.TestPerfomerWithBackoff do
  use PgQueuetopia.Performer

  alias PgQueuetopia.Queue.Job

  @impl true

  def perform(%Job{} = job) do
    PgQueuetopia.TestPerfomer.perform(job)
  end

  def backoff(%Job{}), do: 20 * 1_000
end
