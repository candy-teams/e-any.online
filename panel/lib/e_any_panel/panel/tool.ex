defmodule EAnyPanel.Panel.Tool do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tools" do
    field :name, :string
    field :url, :string
    field :category, :string
    field :source, :string, default: "internal"
    field :icon_url, :string
    field :is_active, :boolean, default: true
    field :description, :string
    field :identity, :string
    belongs_to :secret, EAnyPanel.Panel.Secret

    timestamps()
  end

  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :url, :category, :source, :icon_url, :is_active, :description, :identity, :secret_id])
    |> validate_required([:name, :url, :source])
    |> validate_inclusion(:source, ["internal", "external"])
    |> validate_length(:name, max: 120)
    |> validate_length(:description, max: 1000)
    |> validate_length(:identity, max: 120)
    |> validate_change(:url, fn :url, value ->
      case URI.new(value) do
        {:ok, %URI{scheme: scheme, host: host, userinfo: nil}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" -> []
        _ -> [url: "kullanıcı adı veya şifre içermeyen bir HTTP/HTTPS adresi olmalı"]
      end
    end)
    |> foreign_key_constraint(:secret_id)
  end
end
