defmodule PgQueuetopia do
  @moduledoc """
  Defines a queues machine.

  A PgQueuetopia can manage multiple ordered blocking queues.
  All the queues share only the same scheduler and the same poll interval.
  They are completely independants.

  A PgQueuetopia expects a performer to exist.
  For example, the performer can be implemented like this:

      defmodule MyApp.MailPgQueuetopia.Performer do
        @behaviour PgQueuetopia.Performer

        @impl true
        def perform(%PgQueuetopia.Queue.Job{action: "do_x"}) do
          do_x()
        end

        defp do_x(), do: {:ok, "done"}
      end

  And the PgQueuetopia:

      defmodule MyApp.MailPgQueuetopia do
        use PgQueuetopia,
          otp_app: :my_app,
          performer: MyApp.MailPgQueuetopia.Performer,
          repo: MyApp.Repo
      end

      # config/config.exs
      config :my_app, MyApp.MailPgQueuetopia,
        poll_interval: 60 * 1_000,
        disable?: true

  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Supervisor
      alias PgQueuetopia.Queue.Job

      @type option :: {:poll_interval, non_neg_integer()}

      @otp_app Keyword.fetch!(opts, :otp_app)
      @repo Keyword.fetch!(opts, :repo)
      @performer Keyword.fetch!(opts, :performer) |> to_string()
      @scope __MODULE__ |> to_string()

      @default_poll_interval 60 * 1_000

      defp config(otp_app, queue) when is_atom(otp_app) and is_atom(queue) do
        config = Application.get_env(otp_app, queue, [])
        [otp_app: otp_app] ++ config
      end

      @doc """
      Starts the PgQueuetopia supervisor process.
      The :poll_interval can also be given in order to config the polling interval of the scheduler.
      """
      @spec start_link([option]) :: Supervisor.on_start()
      def start_link(opts \\ []) do
        config = config(@otp_app, __MODULE__)

        poll_interval =
          Keyword.get(opts, :poll_interval) ||
            Keyword.get(config, :poll_interval) ||
            @default_poll_interval

        disable? = Keyword.get(config, :disable?, false)

        opts = [
          repo: @repo,
          poll_interval: poll_interval
        ]

        if disable?, do: :ignore, else: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @impl true
      def init(args) do
        children = [
          {Task.Supervisor, name: task_supervisor()},
          {PgQueuetopia.Scheduler,
           [
             name: scheduler(),
             task_supervisor_name: task_supervisor(),
             repo: Keyword.fetch!(args, :repo),
             scope: @scope,
             poll_interval: Keyword.fetch!(args, :poll_interval)
           ]}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      defp child_name(child) do
        Module.concat(__MODULE__, child)
      end

      @doc """
      Creates a job.

      ## Job options
      A job accepts the following options:

        * `:timeout` - The time in milliseconds to wait for the job to
          finish. (default: 60_000)

        * `:max_backoff` - default to 24 * 3600 * 1_000

        * `:max_attempts` - default to 20.

      It is possible to schedule jobs in the future. In this FIFO, the first_in is determined by the scheduled_at.
      Jobs having the same scheduled_at will be ordered by their id (arrival order).

      ## Examples

          iex> MyApp.MailPgQueuetopia.create_job(
              "mails_queue_1",
              "send_mail",
              %{email_address: "toto@mail.com", body: "Welcome"},
              DateTime.utc_now(),
              [timeout: 1_000, max_backoff: 60_000]
            )
          {:ok, %Job{}}
      """
      @spec create_job(binary, binary, map, DateTime.t(), [Job.option()] | []) ::
              {:error, Ecto.Changeset.t()} | {:ok, Job.t()}
      def create_job(queue, action, params, scheduled_at \\ DateTime.utc_now(), opts \\ [])
          when is_binary(queue) and is_binary(action) and is_map(params) do
        result =
          PgQueuetopia.Queue.create_job(
            @repo,
            @performer,
            @scope,
            queue,
            action,
            params,
            scheduled_at,
            opts
          )

        with {:ok, %Job{}} <- result do
          handle_event(:new_incoming_job)
        end

        result
      end

      @doc """
      Similar to `c:create_job/5` but raises if the changeset is not valid.
      Raises if more than one entry.
      ## Examples
          iex> MyApp.MailQueuetopia.create_job!(
              "mails_queue_1",
              "send_mail",
              %{email_address: "toto@mail.com", body: "Welcome"},
              DateTime.utc_now(),
              [timeout: 1_000, max_backoff: 60_000]
            )
          %Job{}
      """
      @spec create_job!(binary, binary, map, DateTime.t(), [Job.option()] | []) ::
              Job.t()
      def create_job!(queue, action, params, scheduled_at \\ DateTime.utc_now(), opts \\ [])
          when is_binary(queue) and is_binary(action) and is_map(params) do
        PgQueuetopia.Queue.create_job(
          @repo,
          @performer,
          @scope,
          queue,
          action,
          params,
          scheduled_at,
          opts
        )
        |> case do
          {:ok, %Job{} = job} ->
            handle_event(:new_incoming_job)

            job

          {:error, %Ecto.Changeset{} = changeset} ->
            raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
        end
      end

      def list_jobs(opts \\ []) do
        PgQueuetopia.Queue.list_jobs(@repo, opts)
      end

      def handle_event(:new_incoming_job) do
        scheduler_pid = Process.whereis(scheduler())

        if is_pid(scheduler_pid) do
          PgQueuetopia.Scheduler.send_poll(scheduler_pid)
          :ok
        else
          {:error, "#{inspect(__MODULE__)} is down"}
        end
      end

      def repo(), do: @repo
      def performer(), do: @performer
      def scope(), do: @scope

      defp scheduler(), do: child_name("Scheduler")
      defp task_supervisor(), do: child_name("TaskSupervisor")
    end
  end
end
