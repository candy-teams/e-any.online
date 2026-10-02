defmodule EAnyPanel.Repo.Migrations.CreateInfisicalAudits do
  use Ecto.Migration

  def change do
    create table(:infisical_audits) do
      add(:user_id, references(:users, on_delete: :nilify_all))
      add(:operation, :string, null: false)
      add(:secret_name, :string)
      add(:outcome, :string, null: false)
      timestamps(type: :utc_datetime)
    end
  end
end
