defmodule EAnyPanel.Notebook.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :title, :string
    field :body, EAnyPanel.Vault.EncryptedString, redact: true
    # Retained for existing rows; the portal now locks every note.
    field :is_critical, :boolean, default: true
    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :body, :is_critical])
    |> validate_required([:title, :body])
    |> validate_length(:title, max: 200)
    |> validate_length(:body, max: 100_000)
  end
end
