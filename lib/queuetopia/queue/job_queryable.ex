defmodule PgQueuetopia.Queue.JobQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: PgQueuetopia.Queue.Job,
    searchable_fields: [
      :scope,
      :queue,
      :action,
      :params
    ]

  import Ecto.Query

  @filterable_fields ~w(id scope queue action available?)a

  defp search_by_field({:params, value}, dynamic) do
    dynamic([line], ^dynamic or like(fragment("params::text"), ^"%#{value}%"))
  end

  defp filter_by_field({key, _value}, _queryable) when key not in @filterable_fields do
    raise "Filter not implemented"
  end

  defp filter_by_field({:available?, true}, queryable) do
    queryable
    |> where([job], is_nil(job.done_at))
  end
end
