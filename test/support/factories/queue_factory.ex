defmodule PgQueuetopia.Factory.Queue do
  alias PgQueuetopia.Queue.Job
  alias PgQueuetopia.Queue.Lock

  defmacro __using__(_opts) do
    quote do
      def build(:lock, attrs) do
        locked_at = utc_now()
        locked_until = locked_at |> add(3600)

        %Lock{
          scope: "scope_#{System.unique_integer([:positive])}",
          queue: "queue_#{System.unique_integer([:positive])}",
          locked_at: locked_at,
          locked_by_node: Kernel.inspect(Node.self()),
          locked_until: locked_until
        }
        |> struct!(attrs)
      end

      def build(:expired_lock, attrs) do
        lock = build(:lock, attrs)

        %{lock | locked_until: lock.locked_at}
      end

      def build(:job, attrs) do
        %Job{
          scope: "scope_#{System.unique_integer([:positive])}",
          queue: "queue_#{System.unique_integer([:positive])}",
          performer: PgQueuetopia.TestPerfomer |> to_string(),
          action: "action_#{System.unique_integer([:positive])}",
          params: %{"bin_pid" => pid_to_bin()},
          scheduled_at: utc_now(),
          timeout: 5_000,
          max_backoff: 0,
          max_attempts: 20
        }
        |> struct!(attrs)
      end

      def build(:done_job, attrs) do
        job = build(:job, attrs)

        %{job | done_at: utc_now()}
      end

      def build(:raising_job, attrs) do
        job = build(:job, attrs)

        %{job | action: "raise"}
      end

      def build(:slow_job, attrs) do
        duration = attrs |> Keyword.get(:params, %{}) |> Map.get("duration") || 500

        job = build(:job, attrs)
        params = job.params |> Map.put("duration", duration)

        job |> Map.merge(%{action: "sleep", params: params})
      end

      def build(:success_job, attrs) do
        job = build(:job, attrs)

        %{job | action: "success"}
      end

      def build(:failure_job, attrs) do
        job = build(:job, attrs)

        %{job | action: "fail"}
      end
    end
  end
end
