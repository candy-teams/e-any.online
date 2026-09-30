defmodule EAnyPanel.Panel.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmarks" do
    field :title, :string
    field :url, :string
    field :category, :string
    field :note, :string

    timestamps()
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:title, :url, :category, :note])
    |> validate_required([:title, :url])
    |> validate_length(:title, max: 200)
    |> validate_change(:url, fn :url, value ->
      case URI.new(value) do
        {:ok, %URI{scheme: scheme, host: host, userinfo: nil}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" -> []
        _ -> [url: "geçerli bir HTTP/HTTPS adresi olmalı"]
      end
    end)
  end
end
