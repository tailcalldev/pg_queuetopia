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

  defp search_by_field(dynamic, {:params, value}) do
    dynamic([line], ^dynamic or like(fragment("params::text"), ^"%#{value}%"))
  end

  defp filter_by_field(_queryable, {key, _value}) when key not in @filterable_fields do
    raise "Filter not implemented"
  end

  defp filter_by_field(queryable, {:available?, true}) do
    queryable
    |> where([job], is_nil(job.done_at))
  end
end
