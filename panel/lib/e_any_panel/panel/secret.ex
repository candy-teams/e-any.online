defmodule EAnyPanel.Panel.Secret do
  use Ecto.Schema
  import Ecto.Changeset

  # All sensitive fields are encrypted at rest via Cloak (AES-256-GCM).
  # `is_critical` is retained for existing rows; all records require vault re-auth.
  schema "secrets" do
    field :title, :string
    field :username, EAnyPanel.Vault.EncryptedString, redact: true
    field :password, EAnyPanel.Vault.EncryptedString, redact: true
    field :url, :string
    field :notes, EAnyPanel.Vault.EncryptedString, redact: true
    field :is_critical, :boolean, default: true

    timestamps()
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:title, :username, :password, :url, :notes, :is_critical])
    |> validate_required([:title])
  end
end
