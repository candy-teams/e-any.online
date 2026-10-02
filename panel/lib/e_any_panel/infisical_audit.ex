defmodule EAnyPanel.InfisicalAudit do
  @moduledoc false
  use Ecto.Schema

  schema "infisical_audits" do
    field(:user_id, :integer)
    field(:operation, :string)
    field(:secret_name, :string)
    field(:outcome, :string)
    timestamps(type: :utc_datetime)
  end
end
