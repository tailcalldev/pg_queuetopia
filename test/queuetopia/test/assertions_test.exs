defmodule PgQueuetopia.Test.AssertionsTest do
  use PgQueuetopia.DataCase

  import PgQueuetopia.Test.Assertions

  describe "assert_job_created/1" do
    test "when the job has just been created" do
      scope = PgQueuetopia.TestPgQueuetopia.scope()
      queuetopia = Module.safe_concat([scope])

      insert!(:job, scope: scope)

      assert_job_created(queuetopia)
    end

    test "when the job has not been created" do
      assert_raise ExUnit.AssertionError, fn ->
        job = params_for(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

        assert_job_created(PgQueuetopia.TestPgQueuetopia, job)
      end
    end
  end

  describe "assert_job_created/2 for a specific queue" do
    test "when the job has just been created" do
      job = insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

      assert_job_created(PgQueuetopia.TestPgQueuetopia, job.queue)
    end

    test "when the job has not been created for the queue" do
      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{queue: "sample_queue", scope: #{inspect(PgQueuetopia.TestPgQueuetopia.scope())}}

          Found job: nil
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

        assert_job_created(PgQueuetopia.TestPgQueuetopia, "sample_queue")
      end
    end

    test "when the job has not been created at all" do
      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{queue: "sample_queue", scope: #{inspect(PgQueuetopia.TestPgQueuetopia.scope())}}

          Found job: nil
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        assert_job_created(PgQueuetopia.TestPgQueuetopia, "sample_queue")
      end
    end
  end

  describe "assert_job_created/2 for a specific job" do
    test "when the job has just been created" do
      %{id: job_id} =
        insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope(), params: %{b: 1, c: 2})

      job = PgQueuetopia.TestPgQueuetopia.repo().get(PgQueuetopia.Queue.Job, job_id)
      assert_job_created(PgQueuetopia.TestPgQueuetopia, job)
      assert_job_created(PgQueuetopia.TestPgQueuetopia, %{params: %{"c" => 2}})

      assert_job_created(PgQueuetopia.TestPgQueuetopia, %{action: job.action, params: %{"c" => 2}})

      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{params: %{c: 10}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        assert_job_created(PgQueuetopia.TestPgQueuetopia, %{params: %{c: 10}})
      end

      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{action: 10, params: %{"c" => 2}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        assert_job_created(PgQueuetopia.TestPgQueuetopia, %{action: 10, params: %{"c" => 2}})
      end
    end

    test "when the job has not been created" do
      assert_raise ExUnit.AssertionError, fn ->
        job = params_for(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

        assert_job_created(PgQueuetopia.TestPgQueuetopia, job)
      end
    end
  end

  describe "assert_job_created/3 for a specific job and a specific queue" do
    test "when the job has just been created" do
      %{id: job_id} =
        insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope(), params: %{b: 1, c: 2})

      job = PgQueuetopia.TestPgQueuetopia.repo().get(PgQueuetopia.Queue.Job, job_id)
      assert_job_created(PgQueuetopia.TestPgQueuetopia, job.queue, job)
      assert_job_created(PgQueuetopia.TestPgQueuetopia, job.queue, %{params: %{"c" => 2}})

      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{action: 10, params: %{"c" => 2}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        assert_job_created(PgQueuetopia.TestPgQueuetopia, %{action: 10, params: %{"c" => 2}})
      end

      message =
        %ExUnit.AssertionError{
          message: """
          Expected a job matching:

          %{action: 10, params: %{"c" => 2}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        assert_job_created(PgQueuetopia.TestPgQueuetopia, job.queue, %{
          action: 10,
          params: %{"c" => 2}
        })
      end
    end

    test "when the job has not been created for the queue" do
      assert_raise ExUnit.AssertionError, fn ->
        job = insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

        assert_job_created(PgQueuetopia.TestPgQueuetopia, "sample_queue", job)
      end
    end

    test "when the job has not been created at all" do
      assert_raise ExUnit.AssertionError, fn ->
        job = params_for(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

        assert_job_created(PgQueuetopia.TestPgQueuetopia, "sample_queue", job)
      end
    end
  end

  describe "refute_job_created/1" do
    test "when the job is not created" do
      refute_job_created(PgQueuetopia.TestPgQueuetopia)
    end

    test "when the job is created" do
      job = insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope())

      message =
        %ExUnit.AssertionError{
          message: """
          Expected no job matching:

          %{scope: "Elixir.PgQueuetopia.TestPgQueuetopia"}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        refute_job_created(PgQueuetopia.TestPgQueuetopia)
      end
    end
  end

  describe "refute_job_created/2 with queue" do
    test "when the job is not created" do
      refute_job_created(PgQueuetopia.TestPgQueuetopia, "queue_name")
    end

    test "when the job is created" do
      job = insert!(:job, scope: PgQueuetopia.TestPgQueuetopia.scope(), queue: "queue_name")

      message =
        %ExUnit.AssertionError{
          message: """
          Expected no job matching:

          %{queue: "queue_name", scope: "Elixir.PgQueuetopia.TestPgQueuetopia"}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        refute_job_created(PgQueuetopia.TestPgQueuetopia, "queue_name")
      end
    end
  end

  describe "refute_job_created/2 with job" do
    test "when the job is not created" do
      refute_job_created(PgQueuetopia.TestPgQueuetopia, %{action: "foo", params: %{"c" => 2}})
    end

    test "when the job is created" do
      job =
        insert!(:job,
          scope: PgQueuetopia.TestPgQueuetopia.scope(),
          queue: "queue_name",
          action: "foo",
          params: %{"c" => 2}
        )

      message =
        %ExUnit.AssertionError{
          message: """
          Expected no job matching:

          %{action: "foo", params: %{"c" => 2}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        refute_job_created(PgQueuetopia.TestPgQueuetopia, %{action: "foo", params: %{"c" => 2}})
      end
    end
  end

  describe "refute_job_created/3" do
    test "when the job is not created" do
      refute_job_created(PgQueuetopia.TestPgQueuetopia, "queue_name", %{
        action: "foo",
        params: %{"c" => 2}
      })
    end

    test "when the job is created" do
      job =
        insert!(:job,
          scope: PgQueuetopia.TestPgQueuetopia.scope(),
          queue: "queue_name",
          action: "foo",
          params: %{"c" => 2}
        )

      message =
        %ExUnit.AssertionError{
          message: """
          Expected no job matching:

          %{action: "foo", params: %{"c" => 2}}

          Found job: #{inspect(job, pretty: true)}
          """
        }
        |> ExUnit.AssertionError.message()

      assert_raise ExUnit.AssertionError, message, fn ->
        refute_job_created(PgQueuetopia.TestPgQueuetopia, "queue_name", %{
          action: "foo",
          params: %{"c" => 2}
        })
      end
    end
  end
end
