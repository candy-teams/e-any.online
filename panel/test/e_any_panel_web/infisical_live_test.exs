defmodule EAnyPanelWeb.InfisicalLiveTest do
  use EAnyPanelWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Ecto.Query
  alias EAnyPanel.{Accounts, Infisical, Repo}

  setup do
    original = Application.get_env(:e_any_panel, Infisical)
    parent = self()
    file = Path.join(System.tmp_dir!(), "infisical-live-#{System.unique_integer([:positive])}")
    File.write!(file, "fake-token")

    Application.put_env(:e_any_panel, Infisical,
      base_url: "https://proxy.example.test",
      project_id: "test-project",
      environment: "dev",
      secret_path: "/agents",
      token_file: file,
      transport: fn method, url, _, _ ->
        send(parent, {:provider_request, method})

        payload =
          if URI.parse(url).path == "/api/v4/secrets",
            do: %{secrets: [%{secretKey: "KEY", secretValue: "fake-sensitive-value", version: 1}]},
            else: %{secret: %{secretKey: "KEY", secretValue: "fake-sensitive-value"}}

        {:ok, 200, Jason.encode!(payload)}
      end
    )

    on_exit(fn ->
      File.rm(file)

      if original,
        do: Application.put_env(:e_any_panel, Infisical, original),
        else: Application.delete_env(:e_any_panel, Infisical)
    end)

    :ok
  end

  defp sign_in(conn, role, tabs) do
    user =
      Accounts.create_user!(%{
        email: "infisical-#{System.unique_integer([:positive])}@example.test",
        password: "test-only-password-42",
        role: role,
        allowed_tabs: Jason.encode!(tabs)
      })

    {Plug.Test.init_test_session(conn, %{user_id: user.id}), user}
  end

  defp unlock(view) do
    view
    |> form("#infisical-unlock", %{unlock: %{password: "test-only-password-42"}})
    |> render_submit()

    assert has_element?(view, "#infisical-lock")
  end

  test "users without vault permission cannot open the module", %{conn: conn} do
    {conn, _} = sign_in(conn, "viewer", ["tools"])
    assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, "/admin/infisical")
    refute_received {:provider_request, _}
  end

  test "locked reads and forged viewer writes never reach the provider", %{conn: conn} do
    {conn, _} = sign_in(conn, "viewer", ["secrets"])
    {:ok, view, _} = live(conn, "/admin/infisical")
    render_click(view, "read", %{name: "KEY"})
    refute_received {:provider_request, _}
    unlock(view)
    assert_received {:provider_request, :get}
    refute has_element?(view, "#infisical-value")
    refute has_element?(view, "form[id^='infisical-write-']")

    render_submit(view, "save", %{
      credential: %{operation: "update", name: "KEY", value: "forged"}
    })

    refute_received {:provider_request, _}
  end

  test "explicit reads are audited and locking clears the value", %{conn: conn} do
    {conn, user} = sign_in(conn, "admin", [])
    {:ok, view, _} = live(conn, "/admin/infisical")
    unlock(view)
    view |> element("#read-KEY") |> render_click()
    assert has_element?(view, "#infisical-value", "fake-sensitive-value")

    assert Repo.exists?(
             from(a in "infisical_audits",
               where: a.user_id == ^user.id and a.operation == "read" and a.outcome == "ok"
             )
           )

    view |> element("#infisical-lock") |> render_click()
    refute has_element?(view, "#infisical-revealed")
    refute has_element?(view, "#read-KEY")
  end

  test "permission revocation stops an already unlocked connection", %{conn: conn} do
    {conn, user} = sign_in(conn, "manager", ["secrets"])
    {:ok, view, _} = live(conn, "/admin/infisical")
    unlock(view)
    assert_received {:provider_request, :get}

    Repo.update_all(from(u in EAnyPanel.Accounts.User, where: u.id == ^user.id),
      set: [allowed_tabs: "[]"]
    )

    render_click(view, "read", %{name: "KEY"})
    assert_redirect(view, "/login")
    refute_received {:provider_request, _}
  end

  test "explicit writes clear the submitted form and record outcome", %{conn: conn} do
    {conn, user} = sign_in(conn, "manager", ["secrets"])
    {:ok, view, _} = live(conn, "/admin/infisical")
    unlock(view)

    view
    |> form("#infisical-write-0", %{
      credential: %{operation: "create", name: "KEY", value: "test-value"}
    })
    |> render_submit()

    assert_received {:provider_request, :post}
    refute has_element?(view, "#infisical-write-0")
    assert has_element?(view, "#infisical-write-1")

    assert Repo.exists?(
             from(a in "infisical_audits",
               where: a.user_id == ^user.id and a.operation == "create" and a.outcome == "ok"
             )
           )
  end
end
