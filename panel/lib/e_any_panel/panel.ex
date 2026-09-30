defmodule EAnyPanel.Panel do
  @moduledoc """
  Panel data: tools (link registry), bookmarks, notes, secrets and access logs.
  Sensitive fields are encrypted via Cloak. Metadata queries exclude secret
  contents; authenticated LiveView event gates enforce access before reading them.
  """
  import Ecto.Query, warn: false
  alias EAnyPanel.Repo
  alias EAnyPanel.Panel.{Tool, Bookmark, Secret, AccessLog}

  # --- Tools ---------------------------------------------------------------
  def list_tools(active_only \\ false)
  def list_tools(true), do: Repo.all(from t in Tool, where: t.is_active, order_by: t.category)
  def list_tools(false), do: Repo.all(from t in Tool, order_by: t.category)

  def get_tool(id), do: Repo.get(Tool, id)
  def create_tool(attrs), do: %Tool{} |> Tool.changeset(attrs) |> Repo.insert()
  def update_tool(%Tool{} = t, attrs), do: t |> Tool.changeset(attrs) |> Repo.update()
  def delete_tool(%Tool{} = t), do: Repo.delete(t)

  # --- Bookmarks -----------------------------------------------------------
  def list_bookmarks, do: Repo.all(from b in Bookmark, order_by: b.category)
  def get_bookmark(id), do: Repo.get(Bookmark, id)
  def create_bookmark(attrs), do: %Bookmark{} |> Bookmark.changeset(attrs) |> Repo.insert()
  def update_bookmark(%Bookmark{} = b, attrs), do: b |> Bookmark.changeset(attrs) |> Repo.update()
  def delete_bookmark(%Bookmark{} = b), do: Repo.delete(b)

  # Compatibility entrypoints; Notebook owns note storage.
  defdelegate list_notes(), to: EAnyPanel.Notebook, as: :list
  defdelegate list_note_summaries(), to: EAnyPanel.Notebook, as: :summaries
  defdelegate get_note(id), to: EAnyPanel.Notebook, as: :get
  defdelegate create_note(attrs), to: EAnyPanel.Notebook, as: :create
  defdelegate update_note(note, attrs), to: EAnyPanel.Notebook, as: :update
  defdelegate delete_note(note), to: EAnyPanel.Notebook, as: :delete

  # --- Secrets -------------------------------------------------------------
  def list_secrets, do: Repo.all(from s in Secret, order_by: s.title)
  def list_secret_summaries do
    Repo.all(from s in Secret, order_by: s.title, select: struct(s, [:id, :title, :url, :is_critical]))
  end
  def get_secret(id), do: Repo.get(Secret, id)
  def create_secret(attrs), do: %Secret{} |> Secret.changeset(attrs) |> Repo.insert()
  def update_secret(%Secret{} = s, attrs), do: s |> Secret.changeset(attrs) |> Repo.update()
  def delete_secret(%Secret{} = s), do: Repo.delete(s)

  # --- Access logs ---------------------------------------------------------
  def log_access(user_id, kind, id, ip) when kind in [:secret, :note] do
    field = if kind == :secret, do: :secret_id, else: :note_id
    attrs = %{user_id: user_id, ip_address: ip, accessed_at: DateTime.utc_now()}
    attrs = Map.put(attrs, field, id)

    %AccessLog{}
    |> AccessLog.changeset(attrs)
    |> Repo.insert()
  end

  def recent_access(user_id \\ nil, limit \\ 50) do
    base = from a in AccessLog, order_by: [desc: a.accessed_at], limit: ^limit
    if user_id, do: Repo.all(from a in base, where: a.user_id == ^user_id), else: Repo.all(base)
  end

  @doc "Birleşik aktivite akışı: access_logs (secret/note erişimleri)."
  def activity_feed(limit \\ 30) do
    Repo.all(from a in AccessLog, order_by: [desc: a.accessed_at], limit: ^limit)
    |> Enum.map(fn log ->
      kind =
        cond do
          log.secret_id -> "secret"
          log.note_id -> "note"
          true -> "panel"
        end

      %{
        time: log.accessed_at,
        actor: log.user_id,
        object: kind,
        action: "accessed",
        detail: "ip: #{log.ip_address || "-"}"
      }
    end)
  end

  # Search only permitted metadata; encrypted fields are never searched.
  def search(term, tabs \\ [:tools, :bookmarks, :notes, :secrets]) do
    term = String.trim(term || "")
    empty = %{tools: [], bookmarks: [], notes: [], secrets: []}

    if term == "" do
      empty
    else
      pattern = "%#{term}%"

      Enum.reduce(tabs, empty, fn
        :tools, results ->
          Map.put(results, :tools, Repo.all(from t in Tool,
            where: t.is_active and (ilike(t.name, ^pattern) or ilike(t.url, ^pattern) or ilike(t.category, ^pattern))))
        :bookmarks, results ->
          Map.put(results, :bookmarks, Repo.all(from b in Bookmark,
            where: ilike(b.title, ^pattern) or ilike(b.url, ^pattern) or ilike(b.category, ^pattern)))
        :notes, results ->
          Map.put(results, :notes, EAnyPanel.Notebook.search_titles(pattern))
        :secrets, results ->
          Map.put(results, :secrets, Repo.all(from s in Secret, where: ilike(s.title, ^pattern),
            select: struct(s, [:id, :title])))
        _, results -> results
      end)
    end
  end
end
