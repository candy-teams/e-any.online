defmodule EAnyPanel.Repo.Migrations.LinkToolsToVault do
  use Ecto.Migration

  def change do
    alter table(:tools) do
      add :description, :text
      add :identity, :string
      add :secret_id, references(:secrets, on_delete: :nilify_all)
    end

    create index(:tools, [:secret_id])
  end
end
