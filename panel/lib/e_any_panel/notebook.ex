defmodule EAnyPanel.Notebook do
  @moduledoc """
  Encrypted Markdown notebook. The portal calls this context instead of
  querying note storage. Credentials, tools and feed entries are not dependencies.
  """
  import Ecto.Query
  alias EAnyPanel.Repo
  alias EAnyPanel.Notebook.Note

  def list, do: Repo.all(from n in Note, order_by: [desc: n.updated_at, desc: n.id])

  def summaries do
    Repo.all(from n in Note, order_by: [desc: n.updated_at, desc: n.id],
      select: struct(n, [:id, :title, :is_critical]))
  end

  def search_titles(pattern) do
    Repo.all(from n in Note, where: ilike(n.title, ^pattern), limit: 30,
      select: struct(n, [:id, :title, :is_critical]))
  end

  def get(id), do: Repo.get(Note, id)
  def create(attrs), do: %Note{} |> Note.changeset(attrs) |> Repo.insert()
  def update(%Note{} = note, attrs), do: note |> Note.changeset(attrs) |> Repo.update()
  def delete(%Note{} = note), do: Repo.delete(note)
end
