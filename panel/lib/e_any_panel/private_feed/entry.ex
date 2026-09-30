defmodule EAnyPanel.PrivateFeed.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(post blog news video music bookmark)
  def kinds, do: @kinds

  schema "private_feed_entries" do
    field :title, :string
    field :body, :string
    field :url, :string
    field :kind, :string, default: "post"
    field :owner, :string
    field :publishers, {:array, :string}, default: []
    field :topics, {:array, :string}, default: []
    field :publisher_text, :string, virtual: true
    field :topic_text, :string, virtual: true
    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:title, :body, :url, :kind, :owner, :publisher_text, :topic_text])
    |> update_change(:owner, &String.trim/1)
    |> validate_required([:title, :kind, :owner])
    |> validate_inclusion(:kind, @kinds)
    |> validate_length(:title, max: 200)
    |> validate_length(:body, max: 20_000)
    |> validate_length(:owner, max: 120)
    |> validate_length(:publisher_text, max: 1000)
    |> validate_length(:topic_text, max: 1000)
    |> validate_change(:url, fn :url, value ->
      case URI.new(value) do
        {:ok, %URI{scheme: scheme, host: host, userinfo: nil}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" -> []
        _ -> [url: "geçerli bir HTTP/HTTPS adresi olmalı"]
      end
    end)
    |> split_labels(:publisher_text, :publishers)
    |> split_labels(:topic_text, :topics)
    |> remove_owner_from_publishers()
  end

  defp split_labels(changeset, input, output) do
    case fetch_change(changeset, input) do
      {:ok, text} ->
        labels = String.split(text || "", ",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()
        put_change(changeset, output, labels)
      :error -> changeset
    end
  end

  defp remove_owner_from_publishers(changeset) do
    owner = get_field(changeset, :owner)
    publishers = Enum.reject(get_field(changeset, :publishers, []), &(&1 == owner))
    put_change(changeset, :publishers, publishers)
  end
end
