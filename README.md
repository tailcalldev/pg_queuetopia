# PgQueuetopia

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/tailcalldev/pg_queuetopia/CI?cacheSeconds=3600&style=flat-square)](https://github.com/tailcalldev/pg_queuetopia/actions) [![GitHub issues](https://img.shields.io/github/issues-raw/tailcalldev/pg_queuetopia?style=flat-square&cacheSeconds=3600)](https://github.com/tailcalldev/pg_queuetopia/issues) [![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?cacheSeconds=3600?style=flat-square)](http://opensource.org/licenses/MIT) [![Hex.pm](https://img.shields.io/hexpm/v/queuetopia?style=flat-square)](https://hex.pm/packages/pg_queuetopia) [![Hex.pm](https://img.shields.io/hexpm/dt/pg_queuetopia?style=flat-square)](https://hex.pm/packages/pg_queuetopia)

A persistant blocking job queue built with Ecto.  
This repo is a fork of [Queuetopia](https://github.com/annatel/queuetopia) in order to support Postgres.

#### Features

- Persistence — Jobs are stored in a DB and updated after each execution attempt.

- Blocking — A failing job blocks its queue until it is done.

- Dynamicity — Queues are dynamically defined. Once the first job is created
  for the queue, the queue exists.

- Reactivity — Immediatly try to execute a job that has just been created.

- Scheduled Jobs — Allow to schedule job in the future.

- Retries — Failed jobs are retried with a configurable backoff.

- Persistence — Jobs are stored in a DB and updated after each execution attempt.

- Performance — At each poll, only one job per queue is run. Optionnaly, jobs can
  avoid waiting unnecessarily. The performed job triggers an other polling.

- Isolated Queues — Jobs are stored in a single table but are executed in
  distinct queues. Each queue runs in isolation, ensuring that a job in a single
  slow queue can't back up other faster queues and that a failing job in a queue
  don't block other queues.

- Handle Node Duplication — Queues are locked, preventing two nodes to perform
  the same job at the same time.

## Installation

PgQueuetopia is published on [Hex](https://hex.pm/packages/pg_queuetopia).
The package can be installed by adding `pg_queuetopia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_queuetopia, "~> 1.2.0"}
  ]
end
```

After the packages are installed you must create a database migration to
add the pg_queuetopia tables to your database:

```bash
mix ecto.gen.migration create_pg_queuetopia_tables
```

Open the generated migration in your editor and call the `up` and `down`
functions on `PgQueuetopia.Migrations`:

```elixir
defmodule MyApp.Repo.Migrations.CreatePgQueuetopiaTables do
  use Ecto.Migration

  def up do
    PgQueuetopia.Migrations.up()
  end

  def down do
    PgQueuetopia.Migrations.down()
  end
end
```

Now, run the migration to create the table:

```sh
mix ecto.migrate
```

## Usage

### Defining the PgQueuetopia

A PgQueuetopia must be informed a repo to persist the jobs and a performer module,
responsible to execute the jobs.

Define a PgQueuetopia with a repo and a perfomer like this:

```elixir
defmodule MyApp.MailPgQueuetopia do
  use PgQueuetopia,
    repo: MyApp.Repo,
    performer: MyApp.MailPgQueuetopia.Performer
end
```

Define the perfomer, adopting the PgQueuetopia.Performer behaviour, like this:

```elixir
defmodule MyApp.MailPgQueuetopia.Performer do
  @behaviour PgQueuetopia.Performer

  @impl true
  def perform(%PgQueuetopia.Queue.Job{action: "do_x"}) do
    do_x()
  end

  defp do_x(), do: {:ok, "done"}
end
```

### Start the PgQueuetopia

An instance PgQueuetopia is a supervision tree and can be started as a child of a supervisor.

For instance, in the application supervision tree:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.MailPgQueuetopia
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

Or, it can be started directly like this:

```elixir
MyApp.MailPgQueuetopia.start_link()
```

The configuration can be set as below:

```elixir
 # config/config.exs
  config :my_app, MyApp.MailPgQueuetopia,
    poll_interval: 60 * 1_000,
    disable?: true

```

Note that the polling interval is optionnal and is an available param of start_link/1.
By default, it will be set to 60 seconds.


### Feeds your queues

To create a job defines its action and its params and configure its timeout and the max backoff for the retries.
By default, the job timeout is set to 60 seconds, the max backoff to 24 hours and the max attempts to 20.

```elixir
MyApp.MailPgQueuetopia.create_job!("mails_queue_1", "send_mail", %{email_address: "toto@mail.com", body: "Welcome"}, [timeout: 1_000, max_backoff: 60_000])
```

or

```elixir
MyApp.MailPgQueuetopia.create_job("mails_queue_1", "send_mail", %{email_address: "toto@mail.com", body: "Welcome"}, [timeout: 1_000, max_backoff: 60_000])
```

to handle changeset errors.

So, the mails_queue_1 was born and you can add it other jobs as we do above.
When the job creation is out of transaction, Queuetopia is automatically notified about the new job.
Anyway, you can notify the queuetopia about a new created job.

```elixir
MyApp.MailPgQueuetopia.notify(:new_incoming_job)
```

### One DB, many PgQueuetopia

Multiple PgQueuetopia can coexist in your project, e.g your project may own its PgQueuetopia and uses a library
shipping its PgQueuetopia. The both PgQueuetopia may run on the same DB and share the same repo. They will have a different scheduler,
may have a different polling interval. They will be defined a scope to reach only their own jobs,
so the won't interfer each other.


## Test

Rename env/test.env.example to env/test.env, set your params and source it.

```sh
MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate
mix test
```

Thanks to [Oban](https://github.com/sorentwo/oban) and elixir community who inspired the PgQueuetopia development.

