defmodule EAnyPanelWeb.DashboardLiveEnhancementsTest do
  use EAnyPanelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EAnyPanel.Accounts

  defp create_admin(conn) do
    user = Accounts.create_user!(%{
      email: "enhance_#{System.unique_integer([:positive])}@test.local",
      password: "TestSifre123!",
      role: "admin",
      allowed_tabs: "[]"
    })
    conn = log_in_user(conn, user)
    {conn, user}
  end

  test "admin sees notes/tools tabs, search box, and vault lock banner",
       %{conn: conn} do
    {conn, _user} = create_admin(conn)

    {:ok, view, html} = live(conn, "/admin")

    # Yeni sekmeler + arama
    assert html =~ ~s(href="/admin?tab=notes")
    assert html =~ ~s(href="/admin?tab=tools")
    assert html =~ "Ara (bookmark, not, secret, araç)"
    # Kişisel grup başlığı
    assert html =~ "Kişisel"

    # Secrets sekmesine geç
    render_patch(view, "/admin?tab=secrets")
    assert render(view) =~ "Yeni Secret"

    view |> form("#vault-unlock-form", %{password: "TestSifre123!"}) |> render_submit()

    # UI üzerinden kritik bir secret ekleyelim (cast + şifreleme gerçek akıştan)
    view
    |> element("button", "+ Yeni Secret")
    |> render_click()

    view
    |> form("form[phx-submit=\"save_secret\"]")
    |> render_submit(%{
      secret: %{title: "Deneme Secret", password: "gizli-pass"}
    })

    render_click(view, "lock_vault")

    # Secrets sekmesinde vault kilit banner'ı görünür, şifre sızmıyor
    assert render(view) =~ "Vault kilitli"
    refute render(view) =~ "gizli-pass"
  end

  test "admin can save a note through the live view", %{conn: conn} do
    {conn, _user} = create_admin(conn)
    {:ok, view, _html} = live(conn, "/admin?tab=notes")
    view |> form("#vault-unlock-form", %{password: "TestSifre123!"}) |> render_submit()

    view
    |> element("button", "+ Yeni Not")
    |> render_click()

    view
    |> form("form[phx-submit=\"save_note\"]")
    |> render_submit(%{
      note: %{title: "Test notu", body: "İçerik"}
    })

    assert render(view) =~ "Test notu"
  end

  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end