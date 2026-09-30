defmodule EAnyPanelWeb.DashboardLiveTest do
  use EAnyPanelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "dashboard sidebar renders all NPM-style nav items", %{conn: conn} do
    user =
      EAnyPanel.Accounts.create_user!(%{email: "dash@e-any.online", password: "SuperSecret123!", role: "admin"})

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})

    {:ok, _view, html} = live(conn, ~p"/admin?tab=proxy_hosts")

    assert html =~ "Başlangıç"
    assert html =~ "Proxy Hosts"
    assert html =~ "Access Lists"
    assert html =~ "Certificates"
    assert html =~ "Users"
    assert html =~ "Audit Logs"
    assert html =~ "Settings"
  end

  test "dashboard proxy_hosts tab renders card grid container and refresh button", %{conn: conn} do
    user =
      EAnyPanel.Accounts.create_user!(%{email: "dash2@e-any.online", password: "SuperSecret123!", role: "admin"})

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})

    {:ok, _view, html} = live(conn, ~p"/admin?tab=proxy_hosts")

    assert html =~ "Proxy Hosts"
    assert html =~ "Yenile"
  end
end
