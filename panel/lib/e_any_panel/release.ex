defmodule EAnyPanel.Release do
  @moduledoc """
  Used for executing DB release tasks when executed within a Docker release.
  """

  @app :e_any_panel

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Imports a private tool catalog into the tools table. The catalog file lives
  outside the repository (it contains internal addresses) and evaluates to a
  list of maps with :name, :url and optional :category / :description.
  Only missing URLs are inserted; existing tools and their vault links stay
  untouched. Credentials never belong in the catalog.

      bin/e_any_panel eval 'EAnyPanel.Release.import_tools("/path/tool-catalog.exs")'
  """
  def import_tools(path) do
    changesets = read_tool_catalog!(path)
    load_app()

    {:ok, inserted, _} =
      Ecto.Migrator.with_repo(EAnyPanel.Repo, fn repo ->
        Enum.count(changesets, fn changeset ->
          url = Ecto.Changeset.get_field(changeset, :url)
          is_nil(repo.get_by(EAnyPanel.Panel.Tool, url: url)) and match?({:ok, _}, repo.insert(changeset))
        end)
      end)

    IO.puts("Imported #{inserted} of #{length(changesets)} tools")
    inserted
  end

  @doc "Reads and validates a tool catalog file without touching the database."
  def read_tool_catalog!(path) do
    {entries, _} = Code.eval_file(path)
    urls = Enum.map(entries, & &1.url)
    if urls != Enum.uniq(urls), do: raise(ArgumentError, "duplicate URLs in #{path}")

    Enum.map(entries, fn attrs ->
      changeset = EAnyPanel.Panel.Tool.changeset(%EAnyPanel.Panel.Tool{}, Map.put(attrs, :source, "internal"))

      unless changeset.valid? do
        raise ArgumentError, "invalid tool #{inspect(attrs[:name])}: #{inspect(changeset.errors)}"
      end

      changeset
    end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
