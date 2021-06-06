defmodule QueuetopiaTest do
  use PgQueuetopia.DataCase
  alias PgQueuetopia.{TestPgQueuetopia, TestPgQueuetopia_2}
  alias PgQueuetopia.Queue.Job

  setup do
    Application.put_env(:pg_queuetopia, TestPgQueuetopia, disable?: false)
    :ok
  end

  test "multiple instances can coexist" do
    start_supervised!(TestPgQueuetopia)
    start_supervised!(TestPgQueuetopia_2)

    :sys.get_state(TestPgQueuetopia.Scheduler)
    :sys.get_state(TestPgQueuetopia_2.Scheduler)
  end

  describe "start_link/1:  poll_interval option" do
    test "preseance to the param" do
      Application.put_env(:pg_queuetopia, TestPgQueuetopia, poll_interval: 3)

      start_supervised!({TestPgQueuetopia, poll_interval: 4})

      %{poll_interval: 4} = :sys.get_state(TestPgQueuetopia.Scheduler)
    end

    test "when there is no param, try to take the value from the config" do
      Application.put_env(:pg_queuetopia, TestPgQueuetopia, poll_interval: 3)

      start_supervised!(TestPgQueuetopia)

      %{poll_interval: 3} = :sys.get_state(TestPgQueuetopia.Scheduler)
    end

    test "when there is no param and no config, takes the default value" do
      start_supervised!(TestPgQueuetopia)

      %{poll_interval: 60_000} = :sys.get_state(TestPgQueuetopia.Scheduler)
    end
  end

  test "disable? option" do
    Application.put_env(:pg_queuetopia, TestPgQueuetopia, disable?: true)
    start_supervised!(TestPgQueuetopia)

    assert is_nil(Process.whereis(TestPgQueuetopia.Scheduler))
  end

  describe "create_job/5" do
    test "creates the job" do
      jobs_params = params_for(:job)

      opts = [
        timeout: jobs_params.timeout,
        max_backoff: jobs_params.max_backoff,
        max_attempts: jobs_params.max_attempts
      ]

      assert {:ok, %Job{} = job} =
               TestPgQueuetopia.create_job(
                 jobs_params.queue,
                 jobs_params.action,
                 jobs_params.params,
                 jobs_params.scheduled_at,
                 opts
               )

      assert job.scope == TestPgQueuetopia.scope()
      assert job.queue == jobs_params.queue
      assert job.performer == TestPgQueuetopia.performer()
      assert job.action == jobs_params.action
      assert job.params == jobs_params.params
      assert not is_nil(job.scheduled_at)
      assert job.timeout == jobs_params.timeout
      assert job.max_backoff == jobs_params.max_backoff
      assert job.max_attempts == jobs_params.max_attempts
    end

    test "when options are set" do
      %{
        queue: queue,
        action: action,
        params: params,
        timeout: timeout,
        max_backoff: max_backoff,
        max_attempts: max_attempts
      } = params_for(:job)

      assert {:ok,
              %Job{
                queue: ^queue,
                action: ^action,
                params: ^params,
                timeout: ^timeout,
                max_backoff: ^max_backoff,
                max_attempts: ^max_attempts
              }} =
               TestPgQueuetopia.create_job(queue, action, params, utc_now(),
                 timeout: timeout,
                 max_backoff: max_backoff,
                 max_attempts: max_attempts
               )
    end

    test "when timing options are not set, takes the default job timing options" do
      timeout = Job.default_timeout()
      max_backoff = Job.default_max_backoff()
      max_attempts = Job.default_max_attempts()

      %{queue: queue, action: action, params: params} = params_for(:job)

      assert {:ok,
              %Job{
                timeout: ^timeout,
                max_backoff: ^max_backoff,
                max_attempts: ^max_attempts
              }} = TestPgQueuetopia_2.create_job(queue, action, params)
    end

    test "a created job is immediatly tried if the queue is empty (no need to wait the poll_interval)" do
      Application.put_env(:pg_queuetopia, TestPgQueuetopia, poll_interval: 5_000)
      start_supervised!(TestPgQueuetopia)

      %{queue: queue, action: action, params: params} = params_for(:success_job)
      assert {:ok, %Job{id: job_id}} = TestPgQueuetopia.create_job(queue, action, params)

      assert_receive {^queue, ^job_id, :ok}, 1_000

      :sys.get_state(TestPgQueuetopia.Scheduler)
    end
  end

  test "create_job!/5 raises when params are not valid" do
    assert_raise Ecto.InvalidChangesetError, fn ->
      TestPgQueuetopia.create_job!("queue", "action", %{}, DateTime.utc_now(), timeout: -1)
    end
  end

  describe "list_jobs/1" do
    test "list the jobs order by queue and scheduled_at asc" do
      utc_now = utc_now()

      %{id: id_1} = insert!(:success_job, queue: "foo", scheduled_at: utc_now |> add(2400))

      %{id: id_2} = insert!(:success_job, queue: "foo", scheduled_at: utc_now |> add(1200))

      %{id: id_3} = insert!(:success_job, queue: "bar", scheduled_at: utc_now |> add(2400))

      %{id: id_4} = insert!(:success_job, queue: "bar", scheduled_at: utc_now |> add(1200))

      assert %{data: [%{id: ^id_4}, %{id: ^id_3}, %{id: ^id_2}, %{id: ^id_1}], total: 4} =
               TestPgQueuetopia.list_jobs()
    end

    test "filters" do
      %{id: id} = job = insert!(:success_job)

      assert %{data: [%{id: ^id}], total: 1} = TestPgQueuetopia.list_jobs(filters: [id: job.id])

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(filters: [scope: job.scope])

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(filters: [queue: job.queue])

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(filters: [action: job.action])

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(filters: [available?: true])

      assert_raise RuntimeError, "Filter not implemented", fn ->
        TestPgQueuetopia.list_jobs(filters: [params: job.params])
      end

      assert %{data: [], total: 0} = TestPgQueuetopia.list_jobs(filters: [id: id()])
      assert %{data: [], total: 0} = TestPgQueuetopia.list_jobs(filters: [scope: "foo"])
      assert %{data: [], total: 0} = TestPgQueuetopia.list_jobs(filters: [queue: "foo"])
      assert %{data: [], total: 0} = TestPgQueuetopia.list_jobs(filters: [action: "foo"])
    end

    test "search_query" do
      %{id: id} = job = insert!(:success_job, params: %{foo: "bar"})

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(search_query: job.scope |> String.slice(1..10))

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(search_query: job.queue |> String.slice(1..10))

      assert %{data: [%{id: ^id}], total: 1} =
               TestPgQueuetopia.list_jobs(search_query: job.action |> String.slice(1..10))

      assert %{data: [%{id: ^id}], total: 1} = TestPgQueuetopia.list_jobs(search_query: "ar")

      assert %{data: [%{id: ^id}], total: 1} = TestPgQueuetopia.list_jobs(search_query: "oo")

      assert %{data: [], total: 0} = TestPgQueuetopia.list_jobs(search_query: "baz")
    end
  end

  describe "handle_event/1" do
    test "sends a poll message to the scheduler" do
      Application.put_env(:pg_queuetopia, TestPgQueuetopia, poll_interval: 5_000)
      start_supervised!(TestPgQueuetopia)

      scheduler_pid = Process.whereis(TestPgQueuetopia.Scheduler)

      :sys.get_state(TestPgQueuetopia.Scheduler)

      {:messages, messages} = Process.info(scheduler_pid, :messages)
      assert length(messages) == 0

      :sys.get_state(TestPgQueuetopia.Scheduler)

      assert :ok = TestPgQueuetopia.handle_event(:new_incoming_job)
      assert :ok = TestPgQueuetopia.handle_event(:new_incoming_job)
      assert :ok = TestPgQueuetopia.handle_event(:new_incoming_job)
      assert :ok = TestPgQueuetopia.handle_event(:new_incoming_job)
      assert :ok = TestPgQueuetopia.handle_event(:new_incoming_job)

      {:messages, messages} = Process.info(scheduler_pid, :messages)
      assert length(messages) == 1

      :sys.get_state(TestPgQueuetopia.Scheduler)
    end

    test "when the scheduler is down, returns an error tuple" do
      assert {:error, "PgQueuetopia.TestPgQueuetopia is down"} ==
               TestPgQueuetopia.handle_event(:new_incoming_job)
    end
  end
end
