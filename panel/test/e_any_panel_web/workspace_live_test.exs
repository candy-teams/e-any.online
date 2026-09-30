defmodule EAnyPanelWeb.WorkspaceLiveTest do
  use EAnyPanelWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias EAnyPanel.{Accounts, Notebook, Panel, PrivateFeed, Repo}

  defp sign_in(conn, role \\ "admin", tabs \\ []) do
    user = Accounts.create_user!(%{
      email: "workspace-#{System.unique_integer([:positive])}@example.test",
      password: "test-only-password-42", role: role, allowed_tabs: Jason.encode!(tabs)
    })
    {Plug.Test.init_test_session(conn, %{user_id: user.id}), user}
  end

  defp unlock(view) do
    view |> form("#vault-unlock-form", %{password: "test-only-password-42"}) |> render_submit()
    assert has_element?(view, "#vault-lock")
  end

  test "tool validation does not save and editing updates the same row", %{conn: conn} do
    {conn, _} = sign_in(conn)
    {:ok, view, _} = live(conn, "/admin?tab=tools")
    view |> element("#add-activepieces") |> render_click()
    assert has_element?(view, "#tool-form input[name='tool[name]'][value='Activepieces']")
    view |> form("#tool-form", %{tool: %{name: "Activepieces", url: "https://auto.example.test"}}) |> render_change()
    assert Panel.list_tools() == []
    view |> form("#tool-form") |> render_submit()
    [tool] = Panel.list_tools()
    view |> element("#edit-tool-#{tool.id}") |> render_click()
    view |> form("#tool-form", %{tool: %{name: "My automation"}}) |> render_submit()
    assert [%{id: id, name: "My automation"}] = Panel.list_tools()
    assert id == tool.id
  end

  test "locked credentials never reach cards and linking requires both permissions", %{conn: conn} do
    {:ok, secret} = Panel.create_secret(%{title: "Automation login", username: "hidden-user", password: "hidden-password"})
    {:ok, tool} = Panel.create_tool(%{name: "Windmill", url: "https://wind.example.test", secret_id: secret.id})
    {conn, user} = sign_in(conn)
    {:ok, view, _} = live(conn, "/admin?tab=tools")
    refute has_element?(view, "[data-copy], #credential-password")
    render_click(view, "show_tool_secret", %{id: to_string(tool.id)})
    refute has_element?(view, "#credential-dialog")
    unlock(view)
    view |> element("#tool-credential-#{tool.id}") |> render_click()
    assert has_element?(view, "#credential-password[value='hidden-password']")
    assert [%{secret_id: secret_id}] = Panel.recent_access(user.id)
    assert secret_id == secret.id
    view |> element("#copy-password") |> render_click()
    assert_push_event(view, "copy-to-clipboard", %{text: "hidden-password"})
    render_click(view, "lock_vault")
    refute has_element?(view, "#credential-dialog")
    render_click(view, "copy_secret", %{id: to_string(secret.id), field: "password"})
    assert length(Panel.recent_access(user.id)) == 2
  end

  test "tool-only viewer cannot read credentials or mutate tools with forged events", %{conn: conn} do
    {:ok, secret} = Panel.create_secret(%{title: "Private"})
    {:ok, tool} = Panel.create_tool(%{name: "Tool", url: "https://example.test", secret_id: secret.id})
    {conn, _} = sign_in(conn, "viewer", ["tools"])
    {:ok, view, _} = live(conn, "/admin?tab=tools")
    render_click(view, "delete_tool", %{id: to_string(tool.id)})
    assert Panel.get_tool(tool.id)
    render_click(view, "show_tool_secret", %{id: to_string(tool.id)})
    refute has_element?(view, "#credential-dialog")
    refute has_element?(view, "#tool-credential-#{tool.id}")
    render_click(view, "search", %{q: "Private"})
    refute has_element?(view, "#search-results span", "Private")
  end

  test "critical notes require unlocking for reading editing exporting and deleting", %{conn: conn} do
    {:ok, note} = Notebook.create(%{title: "Private note", body: "# hidden-markdown", is_critical: true})
    {conn, _} = sign_in(conn)
    {:ok, view, _} = live(conn, "/admin?tab=notes")
    render_click(view, "open_note_modal", %{id: to_string(note.id)})
    refute has_element?(view, "#note-form")
    render_click(view, "delete_note", %{id: to_string(note.id)})
    assert Notebook.get(note.id)
    unlock(view)
    view |> element("#read-note-#{note.id}") |> render_click()
    assert has_element?(view, "#note-markdown", "# hidden-markdown")
    view |> element("#export-note") |> render_click()
    assert_push_event(view, "download-markdown", %{filename: "Private note.md", body: "# hidden-markdown"})
    render_click(view, "lock_vault")
    refute has_element?(view, "#note-reader")
  end

  test "Markdown import opens an editor without saving until submit", %{conn: conn} do
    {conn, _} = sign_in(conn)
    {:ok, view, _} = live(conn, "/admin?tab=notes")
    unlock(view)
    upload = file_input(view, "#markdown-import", :markdown, [%{
      name: "thoughts.md", content: "# My note\n\nA thought.", type: "text/markdown",
      last_modified: 1_600_000_000_000
    }])
    render_upload(upload, "thoughts.md")
    view |> form("#markdown-import") |> render_submit()
    assert has_element?(view, "#note-form textarea", "# My note")
    assert Notebook.list() == []
    view |> form("#note-form") |> render_submit()
    assert [%{title: "thoughts", body: "# My note\n\nA thought."}] = Notebook.list()
  end

  test "feed is private and validation creates no entries", %{conn: conn} do
    {conn, _} = sign_in(conn)
    {:ok, view, _} = live(conn, "/admin?tab=feed")
    view |> element("#add-feed") |> render_click()
    attrs = %{entry: %{title: "My post", owner: "My company", publisher_text: "My blog, X", kind: "post"}}
    view |> form("#feed-form", attrs) |> render_change()
    assert PrivateFeed.page().entries == []
    view |> form("#feed-form") |> render_submit()
    assert [%{owner: "My company", publishers: ["My blog", "X"]}] = PrivateFeed.page().entries
    assert has_element?(view, "#feed-entries article")
    assert Repo.aggregate(PrivateFeed.Entry, :count) == 1
  end

  test "revoking access invalidates an already open session", %{conn: conn} do
    {conn, user} = sign_in(conn, "manager", ["tools"])
    {:ok, view, _} = live(conn, "/admin?tab=tools")
    {:ok, _} = Accounts.update_user_roles(user, %{allowed_tabs: "[]"})
    render_click(view, "open_tool_modal")
    assert_redirect(view, "/admin")
  end
end
