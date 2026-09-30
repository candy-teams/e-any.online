defmodule EAnyPanel.WorkspaceTest do
  use EAnyPanel.DataCase, async: true

  alias EAnyPanel.{Notebook, Panel, PrivateFeed, Repo}

  test "tool links an existing credential and deleting it preserves the tool" do
    {:ok, secret} = Panel.create_secret(%{title: "Automation"})
    {:ok, tool} = Panel.create_tool(%{name: "Windmill", url: "https://tools.example.test", secret_id: secret.id})
    assert tool.secret_id == secret.id
    assert {:ok, _} = Panel.delete_secret(secret)
    assert Panel.get_tool(tool.id).secret_id == nil
  end

  test "tools reject unsafe URLs and missing credential references" do
    for url <- ["javascript:alert(1)", "https://user:pass@example.test", "file:///tmp/tool", "https://"] do
      assert {:error, changeset} = Panel.create_tool(%{name: "Tool", url: url})
      assert Keyword.has_key?(changeset.errors, :url)
    end

    assert {:error, changeset} = Panel.create_tool(%{name: "Tool", url: "https://example.test", secret_id: 999_999_999})
    assert Keyword.has_key?(changeset.errors, :secret_id)
  end

  test "private feed separates owner from deduplicated publishers and topic tags" do
    {:ok, entry} = PrivateFeed.create(%{
      title: "A thought", kind: "post", owner: "  My company  ",
      publisher_text: "My company, My blog, X, My blog", topic_text: "elixir, notes"
    })
    assert entry.owner == "My company"
    assert entry.publishers == ["My blog", "X"]
    assert entry.topics == ["elixir", "notes"]
    assert {:error, _} = PrivateFeed.create(%{title: "Missing owner", kind: "post"})
  end

  test "bookmark and feed links reject executable URLs" do
    assert {:error, _} = Panel.create_bookmark(%{title: "Unsafe", url: "javascript:alert(1)"})
    assert {:error, _} = PrivateFeed.create(%{title: "Unsafe", kind: "bookmark", owner: "Me", url: "javascript:alert(1)"})
  end

  test "feed paging does not repeat entries" do
    for n <- 1..32 do
      {:ok, _} = PrivateFeed.create(%{title: "Entry #{n}", kind: "news", owner: "Me"})
    end

    first = PrivateFeed.page()
    second = PrivateFeed.page(first.cursor)
    assert length(first.entries) == 30
    assert first.more?
    assert length(second.entries) == 2
    refute second.more?
    assert MapSet.disjoint?(MapSet.new(first.entries, & &1.id), MapSet.new(second.entries, & &1.id))
  end

  test "note bodies are encrypted in storage and excluded from metadata search" do
    body = "# Private heading\n\nDo not search this content."
    {:ok, note} = Notebook.create(%{title: "Meeting", body: body})
    assert Notebook.get(note.id).body == body
    assert hd(Notebook.summaries()).body == nil

    result = Ecto.Adapters.SQL.query!(Repo, "SELECT body FROM notes WHERE id = $1", [note.id])
    assert [[encrypted]] = result.rows
    refute encrypted == body
    assert Panel.search("Private heading", [:notes]).notes == []
    assert [%{id: id, body: nil}] = Panel.search("Meeting", [:notes]).notes
    assert id == note.id
  end

  test "search only returns authorized metadata" do
    {:ok, _} = Panel.create_secret(%{title: "Shared name", username: "private-user", password: "fixture-only"})
    {:ok, _} = Panel.create_bookmark(%{title: "Shared name", url: "https://example.test"})
    results = Panel.search("Shared", [:bookmarks])
    assert length(results.bookmarks) == 1
    assert results.secrets == []
    assert [%{password: nil, username: nil}] = Panel.search("Shared", [:secrets]).secrets
  end
end
