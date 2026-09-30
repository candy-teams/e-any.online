defmodule EAnyPanel.Repo.Migrations.CreatePrivateFeedEntries do
  use Ecto.Migration

  def change do
    create table(:private_feed_entries) do
      add :title, :string, null: false
      add :body, :text
      add :url, :text
      add :kind, :string, null: false
      add :owner, :string, null: false
      add :publishers, {:array, :string}, null: false, default: []
      add :topics, {:array, :string}, null: false, default: []
      timestamps()
    end
  end
end
