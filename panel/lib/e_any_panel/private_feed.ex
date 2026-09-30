defmodule EAnyPanel.PrivateFeed do
  @moduledoc "Private workspace feed. Saving never publishes to an external service."
  import Ecto.Query
  alias EAnyPanel.Repo
  alias EAnyPanel.PrivateFeed.Entry

  def page(before_id \\ nil) do
    query = from e in Entry, order_by: [desc: e.id], limit: 31
    query = if before_id, do: from(e in query, where: e.id < ^before_id), else: query
    rows = Repo.all(query)
    entries = Enum.take(rows, 30)
    %{entries: entries, more?: length(rows) > 30, cursor: List.last(entries) && List.last(entries).id}
  end

  def create(attrs), do: %Entry{} |> Entry.changeset(attrs) |> Repo.insert()
  def get(id), do: Repo.get(Entry, id)
  def delete(%Entry{} = entry), do: Repo.delete(entry)
end
