defmodule EAnyPanelWeb.DashboardLive do
  use EAnyPanelWeb, :live_view

  alias EAnyPanel.Accounts
  alias EAnyPanel.Panel
  alias EAnyPanel.PrivateFeed
  alias EAnyPanel.Notebook
  alias EAnyPanel.NpmClient

  @tabs [
    dashboard: "Başlangıç",
    feed: "Akış",
    landing: "Landing",
    proxy_hosts: "Proxy Hosts",
    access_lists: "Access Lists",
    certificates: "Certificates",
    users: "Users",
    notes: "Notlar",
    tools: "Araçlar",
    bookmarks: "Bookmarks",
    secrets: "Kasa",
    audit_logs: "Audit Logs",
    activity: "Sap",
    settings: "Settings"
  ]

  # Rol bazlı menü görünürlüğü — admin her şeyi görür; manager/viewer
  # sadece kendilerine atanan sekmeleri görür (Accounts.allowed_tabs_for).
  @default_viewer_tabs [:dashboard]

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    visible_tabs = visible_tabs_for(user)

    socket =
      socket
      |> assign(:current_scope, %{user: user})
      |> assign(:tab, :dashboard)
      |> assign(:tabs, @tabs)
      |> assign(:visible_tabs, visible_tabs)
      |> assign(:sidebar_open, false)
      |> assign(:editing_perms_user, nil)
      |> assign(modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}))
      |> assign(:editing, nil)
      |> assign(:selected_secret, nil)
      |> assign(:selected_note, nil)
      |> assign(:feed_form, to_form(%{}))
      |> assign(feed_more: false, feed_cursor: nil)
      |> stream(:feed_entries, [])
      |> allow_upload(:markdown, accept: ~w(.md .markdown), max_entries: 1, max_file_size: 100_000)
      |> assign(:vault_expires_at, nil)
      |> assign(:bookmark_form, to_form(%{}))
      |> assign(:secret_form, to_form(%{}))
      |> assign(:note_form, to_form(%{}))
      |> assign(:tool_form, to_form(%{}))
      |> assign(:search_term, "")
      |> assign(:search_results, nil)
      |> assign(:npm_proxy_hosts, [])
      |> assign(:npm_access_lists, [])
      |> assign(:npm_certificates, [])
      |> assign(:npm_users, [])
      |> assign(:npm_audit_logs, [])
      |> assign(:npm_loaded, false)
      |> assign(:app_users, if(:users in visible_tabs, do: Accounts.list_users(), else: []))
      |> assign(:access_logs, if(:audit_logs in visible_tabs, do: Panel.recent_access(nil, 20), else: []))
      |> assign(:vault_locked, true)
      |> assign(:vault_unlock_modal, false)
      |> assign(:vault_password, to_form(%{}))
      |> attach_hook(:authorize_event, :handle_event, &authorize_event/3)
      |> attach_hook(:authorize_navigation, :handle_params, fn _params, _uri, socket -> authorize_event("nav", %{}, socket) end)
      |> load_collection(:tools)
      |> load_collection(:bookmarks)
      |> load_collection(:notes)
      |> load_collection(:secrets)

    {:ok, socket}
  end

  def handle_params(%{"tab" => tab}, _uri, socket) do
    tab = Enum.find(Keyword.keys(@tabs), &(Atom.to_string(&1) == tab))

    if tab in socket.assigns.visible_tabs do
      {:noreply, socket |> assign(tab: tab, sidebar_open: false) |> maybe_load_npm(tab) |> maybe_load_feed(tab) |> load_collection(tab)}
    else
      # Yetkisiz sekme -> dashboard'a geri at
      {:noreply,
       socket
       |> put_flash(:error, "Bu sekmeye erişim yetkiniz yok.")
       |> push_patch(to: ~p"/admin?tab=dashboard")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # NPM verilerini sadece NPM sekmelerine girilince yükle (mount'u hızlı tut).
  defp maybe_load_npm(socket, tab)
       when tab in [:proxy_hosts, :access_lists, :certificates, :activity] do
    if socket.assigns.npm_loaded do
      socket
    else
      socket
      |> assign(:npm_proxy_hosts, NpmClient.list_proxy_hosts() || [])
      |> assign(:npm_access_lists, NpmClient.list_access_lists() || [])
      |> assign(:npm_certificates, NpmClient.list_certificates() || [])
      |> assign(:npm_users, NpmClient.list_users() || [])
      |> assign(:npm_audit_logs, NpmClient.list_audit_logs() || [])
      |> assign(:npm_loaded, true)
    end
  end

  defp maybe_load_npm(socket, _tab), do: socket

  def handle_event("nav", %{"tab" => tab}, socket) do
    tab_atom = Enum.find(Keyword.keys(@tabs), &(Atom.to_string(&1) == tab))

    if tab_atom in socket.assigns.visible_tabs do
      {:noreply, push_patch(socket, to: ~p"/admin?tab=#{tab}")}
    else
      {:noreply, put_flash(socket, :error, "Bu sekmeye erişim yetkiniz yok.")}
    end
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, not socket.assigns.sidebar_open)}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:npm_proxy_hosts, NpmClient.list_proxy_hosts())
     |> assign(:npm_access_lists, NpmClient.list_access_lists())
     |> assign(:npm_certificates, NpmClient.list_certificates())
     |> assign(:npm_users, NpmClient.list_users())
     |> assign(:npm_audit_logs, NpmClient.list_audit_logs())}
  end

  # --- Search ---------------------------------------------------------------
  def handle_event("search", %{"q" => term}, socket) do
    results = if String.trim(term) == "", do: nil, else: Panel.search(term, socket.assigns.visible_tabs)
    {:noreply, assign(socket, search_term: term, search_results: results)}
  end

  # --- Modal control ------------------------------------------------------
  def handle_event("open_bookmark_modal", %{"id" => id}, socket) do
    bm = Panel.get_bookmark(id)

    {:noreply,
     assign(socket,
       modal: :bookmark,
       editing: bm,
       bookmark_form: to_form(Panel.Bookmark.changeset(bm, %{}))
     )}
  end

  def handle_event("open_bookmark_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :bookmark,
       editing: nil,
       bookmark_form: to_form(Panel.Bookmark.changeset(%Panel.Bookmark{}, %{}))
     )}
  end

  def handle_event("open_secret_modal", %{"id" => id}, socket) do
    with %Panel.Secret{} = s <- Panel.get_secret(id),
         {:ok, _} <- Panel.log_access(socket.assigns.current_user.id, :secret, s.id, nil) do
      {:noreply, assign(socket, modal: :secret, editing: s,
        secret_form: to_form(Panel.Secret.changeset(s, %{})))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Kayıt açılamadı.")}
    end
  end

  def handle_event("open_secret_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :secret,
       editing: nil,
       secret_form: to_form(Panel.Secret.changeset(%Panel.Secret{}, %{}))
     )}
  end

  def handle_event("open_note_modal", %{"id" => id}, socket) do
    with %Notebook.Note{} = n <- Notebook.get(id),
         {:ok, _} <- Panel.log_access(socket.assigns.current_user.id, :note, n.id, nil) do
      {:noreply, assign(socket, modal: :note, editing: n,
        note_form: to_form(Notebook.Note.changeset(n, %{})))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Kayıt açılamadı.")}
    end
  end

  def handle_event("open_note_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :note,
       editing: nil,
       note_form: to_form(Notebook.Note.changeset(%Notebook.Note{}, %{}))
     )}
  end

  def handle_event("open_tool_modal", %{"id" => id}, socket) do
    t = Panel.get_tool(id)

    {:noreply,
     assign(socket, modal: :tool, editing: t, tool_form: to_form(Panel.Tool.changeset(t, %{})))}
  end

  def handle_event("open_tool_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :tool,
       editing: nil,
       tool_form: to_form(Panel.Tool.changeset(%Panel.Tool{}, %{}))
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, editing: nil, selected_secret: nil, selected_note: nil, secret_form: to_form(%{}), note_form: to_form(%{}))}
  end

  # --- Bookmark CRUD ------------------------------------------------------
  def handle_event("save_bookmark", %{"bookmark" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_bookmark(attrs)
        bm -> Panel.update_bookmark(bm, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_collection(:bookmarks)
         |> assign(modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}))
         |> put_flash(:info, "Bookmark kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, bookmark_form: to_form(changeset))}
    end
  end

  def handle_event("delete_bookmark", %{"id" => id}, socket) do
    with bm when not is_nil(bm) <- Panel.get_bookmark(id) do
      Panel.delete_bookmark(bm)
    end

    {:noreply, load_collection(socket, :bookmarks)}
  end

  # --- Secret CRUD --------------------------------------------------------
  def handle_event("save_secret", %{"secret" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_secret(attrs)
        s -> Panel.update_secret(s, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_collection(:secrets)
         |> assign(modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}))
         |> put_flash(:info, "Secret kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, secret_form: to_form(changeset))}
    end
  end

  def handle_event("delete_secret", %{"id" => id}, socket) do
    with sec when not is_nil(sec) <- Panel.get_secret(id) do
      Panel.delete_secret(sec)
    end

    {:noreply, socket |> load_collection(:secrets) |> load_collection(:tools) |> assign(selected_secret: nil)}
  end

  def handle_event("toggle_secret", %{"id" => id}, socket) do
    reveal_secret(socket, id)
  end

  def handle_event("show_tool_secret", %{"id" => id}, socket) do
    case Panel.get_tool(id) do
      %Panel.Tool{secret_id: secret_id} when not is_nil(secret_id) -> reveal_secret(socket, secret_id)
      _ -> {:noreply, put_flash(socket, :error, "Bağlı kasa kaydı bulunamadı.")}
    end
  end

  def handle_event("copy_secret", %{"id" => id, "field" => field}, socket)
      when field in ["username", "password"] do
    case Panel.get_secret(id) do
      nil -> {:noreply, put_flash(socket, :error, "Kasa kaydı bulunamadı.")}
      secret ->
        case Panel.log_access(socket.assigns.current_user.id, :secret, secret.id, nil) do
          {:ok, _} ->
            value = if field == "username", do: secret.username, else: secret.password
            {:noreply, push_event(socket, "copy-to-clipboard", %{text: value || ""})}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Erişim kaydı oluşturulamadı.")}
        end
    end
  end

  def handle_event("unlock_vault", %{"password" => pass}, socket) do
    user = socket.assigns.current_user

    with {:allow, _} <- Hammer.check_rate("vault-unlock:#{user.id}", 60_000, 5),
         :ok <- Accounts.verify_password(user, pass) do
      expires = System.monotonic_time(:millisecond) + 300_000
      Process.send_after(self(), {:lock_vault, expires}, 300_000)

      {:noreply,
       socket
       |> assign(vault_locked: false, vault_expires_at: expires, vault_password: to_form(%{}))
       |> put_flash(:info, "Kasa 5 dakika için açıldı.")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Kasa açılamadı. Şifreni kontrol et veya biraz sonra tekrar dene.")}
    end
  end

  def handle_event("lock_vault", _params, socket), do: {:noreply, lock_vault(socket)}

  def handle_event("open_tool_template", %{"template" => template}, socket) do
    defaults = case template do
      "activepieces" -> %{name: "Activepieces", description: "İçerik yayınlama ve uygulama otomasyonları", category: "Otomasyon"}
      "windmill" -> %{name: "Windmill", description: "Şirket ve proje iş akışları", category: "Otomasyon"}
    end

    {:noreply, assign(socket, modal: :tool, editing: nil,
      tool_form: to_form(Panel.Tool.changeset(%Panel.Tool{}, defaults)))}
  end

  # --- Note CRUD ----------------------------------------------------------
  def handle_event("save_note", %{"note" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Notebook.create(attrs)
        n -> Notebook.update(n, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_collection(:notes)
         |> assign(modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}))
         |> put_flash(:info, "Not kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, note_form: to_form(changeset))}
    end
  end

  def handle_event("delete_note", %{"id" => id}, socket) do
    with n when not is_nil(n) <- Notebook.get(id) do
      Notebook.delete(n)
    end

    {:noreply, load_collection(socket, :notes)}
  end

  # --- Tool CRUD ----------------------------------------------------------
  def handle_event("save_tool", %{"tool" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_tool(attrs)
        t -> Panel.update_tool(t, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_collection(:tools)
         |> assign(modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}))
         |> put_flash(:info, "Araç kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, tool_form: to_form(changeset))}
    end
  end

  def handle_event("delete_tool", %{"id" => id}, socket) do
    with t when not is_nil(t) <- Panel.get_tool(id) do
      Panel.delete_tool(t)
    end

    {:noreply, load_collection(socket, :tools)}
  end

  def handle_event("validate_tool", %{"tool" => attrs}, socket) do
    changeset = Panel.Tool.changeset(socket.assigns.editing || %Panel.Tool{}, attrs)
    {:noreply, assign(socket, :tool_form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("validate_bookmark", %{"bookmark" => attrs}, socket) do
    changeset = Panel.Bookmark.changeset(socket.assigns.editing || %Panel.Bookmark{}, attrs)
    {:noreply, assign(socket, :bookmark_form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("validate_note", %{"note" => attrs}, socket) do
    changeset = Notebook.Note.changeset(socket.assigns.editing || %Notebook.Note{}, attrs)
    {:noreply, assign(socket, :note_form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("validate_secret", %{"secret" => attrs}, socket) do
    changeset = Panel.Secret.changeset(socket.assigns.editing || %Panel.Secret{}, attrs)
    {:noreply, assign(socket, :secret_form, to_form(Map.put(changeset, :action, :validate)))}
  end

  # --- User role management (admin only) ------------------------------------
  def handle_event("toggle_user_perms", %{"user_id" => id}, socket) do
    id = String.to_integer(id)
    current = socket.assigns[:editing_perms_user]
    new = if current == id, do: nil, else: id
    {:noreply, assign(socket, :editing_perms_user, new)}
  end

  def handle_event("update_user_role", %{"user_id" => id, "role" => role}, socket) do
    if socket.assigns.current_user.role == "admin" do
      with user when not is_nil(user) <- Accounts.get_user(id) do
        allowed =
          case role do
            "admin" -> "[]"
            "manager" -> "[]"
            "viewer" -> Jason.encode!(socket.assigns[:perms_for] || [])
            _ -> "[]"
          end

        Accounts.update_user_roles(user, %{role: role, allowed_tabs: allowed})
      end

      {:noreply, assign(socket, :app_users, Accounts.list_users())}
    else
      {:noreply, put_flash(socket, :error, "Sadece admin rol değiştirebilir.")}
    end
  end

  def handle_event("save_user_perms", %{"user_id" => id} = params, socket) do
    tabs = Enum.filter(List.wrap(params["tabs"]), &(&1 in Accounts.all_tabs()))
    if socket.assigns.current_user.role == "admin" do
      with user when not is_nil(user) <- Accounts.get_user(id) do
        Accounts.update_user_roles(user, %{role: user.role, allowed_tabs: Jason.encode!(tabs)})
      end

      {:noreply, assign(socket, :app_users, Accounts.list_users())}
    else
      {:noreply, put_flash(socket, :error, "Sadece admin rol değiştirebilir.")}
    end
  end

  def handle_event("open_feed_modal", _params, socket) do
    {:noreply, assign(socket, modal: :feed, editing: nil,
      feed_form: to_form(PrivateFeed.Entry.changeset(%PrivateFeed.Entry{}, %{})))}
  end

  def handle_event("bookmark_to_feed", %{"id" => id}, socket) do
    case Panel.get_bookmark(id) do
      nil -> {:noreply, put_flash(socket, :error, "Bookmark bulunamadı.")}
      bookmark ->
        attrs = %{title: bookmark.title, url: bookmark.url, body: bookmark.note, kind: "bookmark"}
        {:noreply, assign(socket, modal: :feed, editing: nil,
          feed_form: to_form(PrivateFeed.Entry.changeset(%PrivateFeed.Entry{}, attrs)))}
    end
  end

  def handle_event("validate_feed", %{"entry" => attrs}, socket) do
    changeset = PrivateFeed.Entry.changeset(%PrivateFeed.Entry{}, attrs)
    {:noreply, assign(socket, :feed_form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save_feed", %{"entry" => attrs}, socket) do
    case PrivateFeed.create(attrs) do
      {:ok, _entry} ->
        {:noreply, socket |> assign(modal: nil, feed_form: to_form(%{}))
          |> maybe_load_feed(:feed) |> push_patch(to: ~p"/admin?tab=feed")
          |> put_flash(:info, "Kapalı akışa eklendi. Dış kanallara yayın yapılmadı.")}
      {:error, changeset} -> {:noreply, assign(socket, :feed_form, to_form(changeset))}
    end
  end

  def handle_event("load_more_feed", _params, socket) do
    page = PrivateFeed.page(socket.assigns.feed_cursor)
    {:noreply, socket |> assign(feed_more: page.more?, feed_cursor: page.cursor)
      |> stream(:feed_entries, page.entries, limit: -90)}
  end

  def handle_event("delete_feed", %{"id" => id}, socket) do
    case PrivateFeed.get(id) do
      nil -> {:noreply, socket}
      entry ->
        case PrivateFeed.delete(entry) do
          {:ok, _} -> {:noreply, stream_delete(socket, :feed_entries, entry)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Gönderi silinemedi.")}
        end
    end
  end

  def handle_event("read_note", %{"id" => id}, socket) do
    with %Notebook.Note{} = note <- Notebook.get(id),
         {:ok, _} <- Panel.log_access(socket.assigns.current_user.id, :note, note.id, nil) do
      {:noreply, assign(socket, modal: :read_note, selected_note: note)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not açılamadı.")}
    end
  end

  def handle_event("export_note", %{"id" => id}, socket) do
    with %Notebook.Note{} = note <- Notebook.get(id),
         {:ok, _} <- Panel.log_access(socket.assigns.current_user.id, :note, note.id, nil) do
      filename = String.replace(note.title, ~r/[^\p{L}\p{N} _-]/u, "_") |> String.slice(0, 100)
      {:noreply, push_event(socket, "download-markdown", %{filename: filename <> ".md", body: note.body})}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not dışa aktarılamadı.")}
    end
  end

  def handle_event("validate_markdown_import", _params, socket), do: {:noreply, socket}

  def handle_event("import_markdown", _params, socket) do
    {complete, pending} = uploaded_entries(socket, :markdown)

    if length(complete) == 1 and pending == [] and upload_errors(socket.assigns.uploads.markdown) == [] do
      [result] = consume_uploaded_entries(socket, :markdown, fn %{path: path}, entry ->
        result = with {:ok, body} <- File.read(path), true <- String.valid?(body) do
          {:ok, %{title: Path.rootname(entry.client_name), body: body, is_critical: true}}
        else
          _ -> :error
        end
        {:ok, result}
      end)

      case result do
        {:ok, attrs} -> {:noreply, assign(socket, modal: :note, editing: nil,
          note_form: to_form(Notebook.Note.changeset(%Notebook.Note{}, attrs)))}
        :error -> {:noreply, put_flash(socket, :error, "UTF-8 kodlamalı bir Markdown dosyası seç.")}
      end
    else
      {:noreply, put_flash(socket, :error, "En fazla 100 KB olan tek bir .md dosyası seç ve yüklemenin tamamlanmasını bekle.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} dashboard>
      <div id="workspace" class="eany-workspace min-h-screen bg-base-200 flex">
        <!-- Mobile overlay -->
        <%= if @sidebar_open do %>
          <div class="fixed inset-0 bg-black/40 z-40 lg:hidden" phx-click="toggle_sidebar"></div>
        <% end %>
        
    <!-- Sidebar -->
        <aside class={
          "w-64 bg-base-100 min-h-screen p-4 flex flex-col border-r border-base-300 z-50 " <>
            "fixed inset-y-0 left-0 transform transition-transform duration-200 lg:static lg:translate-x-0 " <>
            (if @sidebar_open, do: "translate-x-0", else: "-translate-x-full")
        }>
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-2">
              <span class="eany-wordmark">e-any.online</span>
            </div>
            <button class="btn btn-ghost btn-sm lg:hidden" phx-click="toggle_sidebar" aria-label="Menüyü kapat">✕</button>
          </div>

          <nav aria-label="Ana menü" class="flex-1">
            <p class="px-3 text-xs uppercase tracking-wider opacity-50 mt-4 mb-2">Kişisel çalışma alanı</p>
            <ul class="menu gap-1">
              <li :for={{tab, label, icon} <- [{:dashboard, "Başlangıç", "hero-squares-2x2"}, {:feed, "Akış", "hero-rectangle-stack"}, {:bookmarks, "Bookmarklar", "hero-bookmark"}, {:secrets, "Kasa", "hero-key"}, {:tools, "Araçlar", "hero-command-line"}, {:notes, "Notlar", "hero-document-text"}]} :if={tab in @visible_tabs}>
                <.link patch={~p"/admin?tab=#{tab}"} id={"nav-#{tab}"} class={active(@tab, tab)} aria-current={if @tab == tab, do: "page", else: nil}>
                  <.icon name={icon} class="size-5" />{label}
                </.link>
              </li>
            </ul>
            <details :if={Enum.any?([:proxy_hosts, :access_lists, :certificates, :users, :audit_logs, :activity, :settings, :landing], &(&1 in @visible_tabs))} class="mt-6" open={@tab in [:proxy_hosts, :access_lists, :certificates, :users, :audit_logs, :activity, :settings, :landing]}>
              <summary class="cursor-pointer px-3 py-2 text-sm opacity-60">Yönetim</summary>
              <ul class="menu menu-sm">
                <li :for={{tab, label} <- [{:proxy_hosts, "Proxy Hosts"}, {:access_lists, "Access Lists"}, {:certificates, "Certificates"}, {:users, "Users"}, {:audit_logs, "Audit Logs"}, {:activity, "Sap"}, {:settings, "Settings"}, {:landing, "Landing"}]} :if={tab in @visible_tabs}>
                  <.link patch={~p"/admin?tab=#{tab}"} class={active(@tab, tab)}>{label}</.link>
                </li>
              </ul>
            </details>
          </nav>

          <div class="mt-auto pt-4 border-t border-base-300 text-xs opacity-60">
            <span class="break-all">{@current_user.email}</span>
            <.form for={%{}} phx-submit="logout" class="mt-2">
              <button type="submit" class="btn btn-ghost btn-xs">Çıkış yap</button>
            </.form>
          </div>
        </aside>
        
    <!-- Content -->
        <main class="flex-1 p-4 sm:p-6 overflow-x-auto">
          <div class="flex flex-wrap justify-between items-center mb-4 gap-2">
            <div class="flex items-center gap-2">
              <button class="btn btn-ghost btn-sm lg:hidden" phx-click="toggle_sidebar" aria-label="Menüyü aç" aria-expanded={to_string(@sidebar_open)}>☰</button>
              <h1 class="text-xl sm:text-2xl font-semibold">{@tabs[@tab]}</h1>
            </div>
            <div class="flex items-center gap-2">
              <!-- Global search -->
              <.form for={%{}} id="workspace-search" phx-submit="search" class="flex items-center gap-2">
                <input
                  id="workspace-search-input"
                  type="search"
                  name="q"
                  value={@search_term}
                  placeholder="Başlık veya etiket ara"
                  aria-label="Bookmark, not, kasa ve araç başlıklarında ara"
                  class="input input-sm input-bordered w-48 sm:w-64"
                />
                <button class="btn btn-sm btn-outline" type="submit">Ara</button>
              </.form>
              <button :if={@current_user.role == "admin" and @tab in [:proxy_hosts, :access_lists, :certificates, :activity]} class="btn btn-sm btn-outline" phx-click="refresh">Yenile</button>
            </div>
          </div>

          <%= if @search_results do %>
            <div class="mb-6 p-4 bg-base-100 rounded-box" id="search-results">
              <div class="flex justify-between items-center mb-3">
                <h2 class="font-semibold">Sonuçlar: "{@search_term}"</h2>
                <button class="btn btn-ghost btn-xs" phx-click={JS.push("search", value: %{q: ""})}>
                  ✕
                </button>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <%= if Enum.empty?(@search_results.tools) and Enum.empty?(@search_results.bookmarks) and Enum.empty?(@search_results.notes) and Enum.empty?(@search_results.secrets) do %>
                  <div class="col-span-full text-center opacity-50 py-6">Sonuç yok</div>
                <% end %>
                <%= for t <- @search_results.tools do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-info badge-xs shrink-0">Araç</span>
                    <a href={t.url} target="_blank" rel="noopener" class="link link-primary truncate">
                      {t.name}
                    </a>
                  </div>
                <% end %>
                <%= for b <- @search_results.bookmarks do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-secondary badge-xs shrink-0">Bookmark</span>
                    <a href={b.url} target="_blank" rel="noopener" class="link link-primary truncate">
                      {b.title}
                    </a>
                  </div>
                <% end %>
                <%= for n <- @search_results.notes do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-warning badge-xs shrink-0">Not</span>
                    <button
                      class="link link-primary truncate"
                      phx-click="read_note" disabled={@vault_locked}
                      phx-value-id={n.id}
                    >
                      {n.title}
                    </button>
                  </div>
                <% end %>
                <%= for s <- @search_results.secrets do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-error badge-xs shrink-0">Secret</span>
                    <span class="truncate">{s.title}</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <section :if={@tab in [:tools, :notes, :secrets] and (:secrets in @visible_tabs or :notes in @visible_tabs)} id="vault-controls" class="rounded-box border border-base-300 bg-base-100 p-4 mb-5">
            <%= if @vault_locked do %>
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div><h2 class="font-semibold">Vault kilitli</h2><p class="text-sm opacity-70">Not ve erişim bilgilerini açmak için şifreni doğrula.</p></div>
                <.form for={@vault_password} id="vault-unlock-form" phx-submit="unlock_vault" class="flex flex-wrap gap-2">
                  <.input type="password" name="password" value="" placeholder="Hesap şifren" autocomplete="current-password" required />
                  <button id="vault-unlock" type="submit" class="btn btn-primary">Kasayı aç</button>
                </.form>
              </div>
            <% else %>
              <div class="flex items-center justify-between gap-3"><p class="text-sm">Kasa açık; 5 dakika sonra otomatik kilitlenir.</p><button id="vault-lock" phx-click="lock_vault" class="btn btn-sm btn-outline">Kilitle</button></div>
            <% end %>
          </section>

          <%= case @tab do %>
            <% :feed -> %>
              <div class="max-w-3xl mx-auto">
                <div class="flex items-center justify-between gap-4 mb-5">
                  <div><h2 class="text-lg font-semibold">Senin akışın</h2><p class="text-sm opacity-60">Yazılar, haberler ve kaydetmeye değer şeyler. Yalnızca yetkili kullanıcılar görür.</p></div>
                  <button :if={@current_user.role in ["admin", "manager"]} id="add-feed" phx-click="open_feed_modal" class="btn btn-primary btn-sm"><.icon name="hero-plus" class="size-4" /> Ekle</button>
                </div>
                <div id="feed-entries" phx-update="stream" class="space-y-4">
                  <p id="feed-empty" class="hidden only:block p-10 text-center border border-dashed border-base-300 rounded-box">İlk yazını ekle veya bir bookmarkı akışa taşı.</p>
                  <article :for={{dom_id, entry} <- @streams.feed_entries} id={dom_id} class="card bg-base-100 border border-base-300">
                    <div class="card-body p-5 sm:p-6">
                      <div class="flex flex-wrap gap-2 items-center text-xs">
                        <span class="badge badge-primary badge-sm" title="İçerik sahibi">{entry.owner}</span>
                        <span class="opacity-60">{feed_kind(entry.kind)} · {Calendar.strftime(entry.inserted_at, "%d.%m.%Y")}</span>
                        <span class="badge badge-ghost badge-sm">Kapalı</span>
                      </div>
                      <h3 class="text-lg font-semibold mt-2">{entry.title}</h3>
                      <p :if={entry.body} class="whitespace-pre-wrap break-words text-sm leading-relaxed">{entry.body}</p>
                      <a :if={entry.url} href={entry.url} target="_blank" rel="noopener noreferrer" class="link link-primary text-sm break-all">Kaynağı aç <.icon name="hero-arrow-top-right-on-square" class="size-4" /></a>
                      <div :if={entry.topics != []} class="flex flex-wrap gap-2 mt-2"><span :for={topic <- entry.topics} class="text-xs opacity-60">#{topic}</span></div>
                      <div :if={entry.publishers != []} class="border-t border-base-200 pt-3 mt-2">
                        <p class="text-xs opacity-60 mb-2">Planlanan yayıncılar · dış yayın bağlantısı henüz kurulmadı</p>
                        <span :for={publisher <- entry.publishers} class="badge badge-outline badge-sm mr-1">{publisher}</span>
                      </div>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"delete-feed-#{entry.id}"} phx-click="delete_feed" phx-value-id={entry.id} data-confirm="Gönderi kapalı akıştan silinsin mi?" class="btn btn-ghost btn-xs self-end text-error">Sil</button>
                    </div>
                  </article>
                </div>
                <button :if={@feed_more} id="feed-more" class="btn btn-outline w-full mt-5" phx-click="load_more_feed">Daha fazla göster</button>
              </div>
            <% :landing -> %>
              <section class="max-w-2xl py-6">
                <p class="mb-4">Kayıtlarına ve araçlarına çalışma alanından eriş.</p>
                <.link patch={~p"/admin?tab=dashboard"} class="btn btn-primary">Çalışma alanını aç</.link>
              </section>
            <% :dashboard -> %>
              <section id="workspace-home" class="max-w-5xl mx-auto py-6 sm:py-10">
                <h2 class="text-lg font-semibold mb-4">Ne açmak istiyorsun?</h2>
                <div class="eany-directory">
                  <.link :for={{tab, title, description, icon} <- [
                    {:feed, "Akış", "Yazılar, haberler ve ilham veren şeyler.", "hero-rectangle-stack"},
                    {:bookmarks, "Bookmarklar", "Tekrar dönmek istediğin bağlantılar.", "hero-bookmark"},
                    {:notes, "Notlar", "Düşüncelerin için Markdown sayfaları.", "hero-document-text"},
                    {:secrets, "Kasa", "İhtiyaç duyduğunda açılan erişim bilgileri.", "hero-key"},
                    {:tools, "Araçlar", "Şirket ve projelerin için uygulamalar.", "hero-command-line"}
                  ]} :if={tab in @visible_tabs} patch={~p"/admin?tab=#{tab}"} id={"home-#{tab}"} class="eany-directory-row">
                    <.icon name={icon} class="size-5" />
                    <div><h3 class="font-semibold">{title}</h3><p class="text-sm eany-muted mt-1">{description}</p></div>
                    <.icon name="hero-arrow-right" class="size-4" />
                  </.link>
                </div>
              </section>
            <% :proxy_hosts -> %>
              <!-- Card view (mobile + desktop grid) -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mb-6">
                <%= for h <- @npm_proxy_hosts do %>
                  <div class={"card bg-base-100  border-t-4 " <> (if h.ssl == "Let's Encrypt", do: "border-primary", else: "border-base-300")}>
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base leading-tight">
                          <a
                            href={"https://#{h.domain}"}
                            class="link link-primary hover:link-accent"
                            target="_blank"
                            rel="noopener"
                          >
                            {h.domain}
                          </a>
                        </h3>
                        <span class="badge badge-success gap-1 shrink-0">
                          <span class="w-2 h-2 rounded-full bg-success inline-block"></span>Online
                        </span>
                      </div>
                      <p class="text-xs font-mono opacity-60 truncate mt-1">{h.forward_url}</p>
                      <div class="flex flex-wrap gap-1.5 mt-3">
                        <span class={"badge badge-sm " <> (if h.ssl == "Let's Encrypt", do: "badge-primary", else: "badge-ghost")}>
                          {if h.ssl == "Let's Encrypt", do: "🔒 ", else: "🌐 "}{h.ssl}
                        </span>
                        <span class="badge badge-sm badge-outline">{h.access}</span>
                        <%= if h.block_exploits do %>
                          <span class="badge badge-sm badge-warning">Exploit Guard</span>
                        <% end %>
                      </div>
                      <p class="text-[11px] opacity-40 mt-3">Created: {h.created_on}</p>
                    </div>
                  </div>
                <% end %>
              </div>
              
    <!-- Table view (desktop) -->
              <div class="overflow-x-auto hidden lg:block">
                <table class="table table-zebra">
                  <thead>
                    <tr>
                      <th>Domain</th>
                      <th>SSL</th>
                      <th>Access</th>
                      <th>Hedef</th>
                      <th>Created</th>
                      <th>Durum</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for h <- @npm_proxy_hosts do %>
                      <tr>
                        <td>
                          <a href={"https://#{h.domain}"} class="link" target="_blank" rel="noopener">
                            {h.domain}
                          </a>
                        </td>
                        <td>{h.ssl}</td>
                        <td>{h.access}</td>
                        <td class="text-sm opacity-70">{h.forward_url}</td>
                        <td class="text-sm opacity-70">{h.created_on}</td>
                        <td><span class="badge badge-success badge-sm">Online</span></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% :access_lists -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Clients</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for a <- @npm_access_lists do %>
                    <tr>
                      <td>{a.id}</td>
                      <td>{a.name}</td>
                      <td>{a.clients}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :certificates -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Domain</th>
                    <th>Expires</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for c <- @npm_certificates do %>
                    <tr>
                      <td>{c.id}</td>
                      <td>{c.domain}</td>
                      <td class="text-sm opacity-70">{c.expires_on}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :users -> %>
              <div class="space-y-6">
                <div>
                  <h2 class="text-lg font-semibold mb-2">NPM Users</h2>
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Email</th>
                        <th>Name</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for u <- @npm_users do %>
                        <tr>
                          <td>{u.id}</td>
                          <td>{u.email}</td>
                          <td>{u.name}</td>
                          <td>{if u.disabled, do: "Disabled", else: "Active"}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
                <div>
                  <h2 class="text-lg font-semibold mb-2">Panel Users</h2>
                  <p class="text-xs opacity-60 mb-2">
                    Rol: <b>admin</b>
                    tüm sekmeleri görür · <b>manager</b>
                    Dashboard + Sap · <b>viewer</b>
                    sadece atanan sekmeler. "İzinler" butonu ile sekme bazlı yetki verilir.
                  </p>
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Email</th>
                        <th>Rol</th>
                        <th>2FA</th>
                        <th>İzinler</th>
                        <th>Sekmeler</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for u <- @app_users do %>
                        <tr>
                          <td>{u.id}</td>
                          <td>{u.email}</td>
                          <td>
                            <.form
                              for={%{}}
                              phx-submit="update_user_role"
                              phx-value-user_id={u.id}
                              class="inline"
                            >
                              <select
                                name="role"
                                class="select select-xs select-bordered"
                                phx-change="update_user_role"
                                phx-value-user_id={u.id}
                              >
                                <%= for r <- ["viewer", "manager", "admin"] do %>
                                  <option value={r} selected={u.role == r}>{r}</option>
                                <% end %>
                              </select>
                            </.form>
                          </td>
                          <td>{if u.totp_secret, do: "✓", else: "—"}</td>
                          <td>
                            <button
                              class="btn btn-xs btn-outline"
                              phx-click="toggle_user_perms"
                              phx-value-user_id={u.id}
                            >
                              İzinler
                            </button>
                            <%= if @editing_perms_user == u.id do %>
                              <div class="mt-2 p-2 bg-base-200 rounded">
                                <p class="text-xs mb-1">Sekme bazlı yetki:</p>
                                <.form
                                  for={%{}}
                                  phx-submit="save_user_perms"
                                  phx-value-user_id={u.id}
                                >
                                  <div class="flex flex-wrap gap-1">
                                    <%= for t <- Keyword.keys(@tabs) do %>
                                      <label class="flex items-center gap-1 text-xs">
                                        <input
                                          type="checkbox"
                                          name="tabs[]"
                                          value={t}
                                          checked={Accounts.can_access_tab?(u, to_string(t))}
                                          class="checkbox checkbox-xs"
                                        />
                                        {t}
                                      </label>
                                    <% end %>
                                  </div>
                                  <button type="submit" class="btn btn-xs btn-primary mt-2">
                                    Kaydet
                                  </button>
                                </.form>
                              </div>
                            <% end %>
                          </td>
                          <td class="text-xs opacity-60">
                            <%= case u.role do %>
                              <% "admin" -> %>
                                tümü
                              <% "manager" -> %>
                                dashboard, sap
                              <% _ -> %>
                                <%= Accounts.allowed_tabs_for(u) |> case do %>
                                  <% :all -> %>
                                    tümü
                                  <% tabs when is_list(tabs) -> %>
                                    Enum.join(tabs, ", ")
                                  <% _ -> %>
                                    —
                                <% end %>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% :audit_logs -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Object</th>
                    <th>Action</th>
                    <th>Actor</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for l <- @npm_audit_logs do %>
                    <tr>
                      <td class="text-sm opacity-70">{l.time}</td>
                      <td>{l.object}</td>
                      <td>{l.action}</td>
                      <td class="text-sm opacity-70">{l.actor}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :notes -> %>
              <div class="flex flex-wrap items-center justify-between gap-3 mb-5">
                <div><h2 class="text-lg font-semibold">Düşüncelerine yer aç</h2><p class="text-sm opacity-60">Markdown notları. Şifreli saklanır, .md dosyası olarak taşınabilir.</p></div>
                <button :if={@current_user.role in ["admin", "manager"]} id="add-note" class="btn btn-primary btn-sm" phx-click="open_note_modal" disabled={@vault_locked}><.icon name="hero-plus" class="size-4" /> Yeni Not</button>
              </div>
              <.form :if={not @vault_locked and @current_user.role in ["admin", "manager"]} for={%{}} id="markdown-import" phx-submit="import_markdown" phx-change="validate_markdown_import" class="flex flex-wrap gap-3 items-center mb-5">
                <label for={@uploads.markdown.ref} class="text-sm">.md içe aktar · en fazla 100 KB</label>
                <.live_file_input upload={@uploads.markdown} class="file-input file-input-sm max-w-xs" />
                <span :for={entry <- @uploads.markdown.entries} class="text-xs">{entry.client_name} · %{entry.progress}</span>
                <span :for={error <- upload_errors(@uploads.markdown)} class="text-xs text-error">{error}</span>
                <span :for={entry <- @uploads.markdown.entries} class="text-xs text-error"><span :for={error <- upload_errors(@uploads.markdown, entry)}>{error}</span></span>
                <button type="submit" class="btn btn-sm btn-outline">Editörde aç</button>
              </.form>
              <div id="note-cards" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                <article :for={{dom_id, n} <- @streams.note_cards} id={dom_id} class="card bg-base-100 border border-base-300">
                  <div class="card-body p-5">
                    <.icon name="hero-document-text" class="size-6 text-primary" />
                    <h3 class="card-title text-base mt-2">{n.title}</h3>
                    <p class="text-xs opacity-50">Markdown · şifreli not</p>
                    <div class="card-actions mt-3">
                      <button id={"read-note-#{n.id}"} phx-click="read_note" phx-value-id={n.id} disabled={@vault_locked} class="btn btn-sm btn-outline">Oku</button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"edit-note-#{n.id}"} phx-click="open_note_modal" phx-value-id={n.id} disabled={@vault_locked} class="btn btn-sm btn-ghost">Düzenle</button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"delete-note-#{n.id}"} phx-click="delete_note" phx-value-id={n.id} disabled={@vault_locked} data-confirm="Not silinsin mi?" class="btn btn-sm btn-ghost text-error">Sil</button>
                    </div>
                  </div>
                </article>
                <p id="notes-empty" class="hidden only:block col-span-full border border-dashed border-base-300 rounded-box p-10 text-center opacity-60">Bir düşünce, toplantı notu veya proje fikriyle başla.</p>
              </div>
            <% :tools -> %>
              <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
                <p class="text-sm opacity-70">Şirket ve projelerinin araçları, adresleri ve kasa bağlantıları.</p>
                <div :if={@current_user.role in ["admin", "manager"]} class="flex flex-wrap gap-2">
                  <button id="add-activepieces" class="btn btn-sm btn-outline" phx-click="open_tool_template" phx-value-template="activepieces">Activepieces ekle</button>
                  <button id="add-windmill" class="btn btn-sm btn-outline" phx-click="open_tool_template" phx-value-template="windmill">Windmill ekle</button>
                  <button id="add-tool" class="btn btn-primary btn-sm" phx-click="open_tool_modal">
                    <.icon name="hero-plus" class="size-4" /> Yeni araç
                  </button>
                </div>
              </div>
              <div id="tool-cards" phx-update="stream" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
                <div id="tools-empty" class="hidden only:block col-span-full rounded-box border border-dashed border-base-300 p-10 text-center">
                  <h2 class="font-semibold">Araçların burada toplansın</h2>
                  <p class="text-sm opacity-70 mt-2">Bir araç ekle, gerçek adresini gir ve istersen kasandaki erişim kaydını bağla.</p>
                </div>
                <article :for={{dom_id, t} <- @streams.tool_cards} id={dom_id} class="card bg-base-100 border border-base-300">
                  <div class="card-body p-5 gap-3">
                    <div class="flex items-start justify-between gap-2">
                      <h2 class="card-title text-base">{t.name}</h2>
                      <span :if={not t.is_active} class="badge badge-ghost badge-sm">Pasif</span>
                    </div>
                    <p :if={t.description} class="text-sm opacity-70">{t.description}</p>
                    <p class="text-xs break-all opacity-60">{t.url}</p>
                    <div class="flex flex-wrap gap-2">
                      <span :if={t.category} class="badge badge-outline badge-sm">{t.category}</span>
                      <span :if={t.identity} class="badge badge-ghost badge-sm">{t.identity}</span>
                    </div>
                    <div class="card-actions mt-2">
                      <a :if={t.is_active} id={"open-tool-#{t.id}"} href={t.url} target="_blank" rel="noopener noreferrer" class="btn btn-primary btn-sm">
                        <.icon name="hero-arrow-top-right-on-square" class="size-4" /> Aç
                      </a>
                      <button :if={t.secret_id && :secrets in @visible_tabs} id={"tool-credential-#{t.id}"} class="btn btn-outline btn-sm" phx-click="show_tool_secret" phx-value-id={t.id} disabled={@vault_locked}>
                        <.icon name="hero-key" class="size-4" /> Erişim bilgileri
                      </button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"edit-tool-#{t.id}"} class="btn btn-ghost btn-sm" phx-click="open_tool_modal" phx-value-id={t.id}>Düzenle</button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"delete-tool-#{t.id}"} class="btn btn-ghost btn-sm text-error" phx-click="delete_tool" phx-value-id={t.id} data-confirm="Araç kaydı silinsin mi? Kasa kaydı korunur.">Sil</button>
                    </div>
                    <p :if={t.secret_id && @vault_locked && :secrets in @visible_tabs} class="text-xs opacity-60">Erişim bilgileri için kasanın kilidini aç.</p>
                  </div>
                </article>
              </div>
            <% :bookmarks -> %>
              <div class="flex justify-end mb-4">
                <button :if={@current_user.role in ["admin", "manager"]} id="add-bookmark" class="btn btn-primary btn-sm" phx-click="open_bookmark_modal">
                  + Yeni Bookmark
                </button>
              </div>
              <div id="bookmark-cards" phx-update="stream" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                <%= for {dom_id, bm} <- @streams.bookmark_cards do %>
                  <div id={dom_id} class="card bg-base-100 border border-base-300">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base truncate">
                          <a href={bm.url} target="_blank" rel="noopener" class="link link-primary">
                            {bm.title}
                          </a>
                        </h3>
                        <div class="flex gap-1 shrink-0">
                          <button
                            class="btn btn-ghost btn-xs"
                            :if={@current_user.role in ["admin", "manager"]}
                            phx-click="open_bookmark_modal"
                            phx-value-id={bm.id}
                            title="Düzenle"
                          >
                            ✏️
                          </button>
                          <button
                            class="btn btn-ghost btn-xs text-error"
                            :if={@current_user.role in ["admin", "manager"]}
                            phx-click="delete_bookmark"
                            phx-value-id={bm.id}
                            data-confirm="Silinsin mi?"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                      <p class="text-sm opacity-70 truncate">{bm.url}</p>
                      <%= if bm.category do %>
                        <span class="badge badge-sm badge-outline mt-2 w-fit">{bm.category}</span>
                      <% end %>
                      <button :if={:feed in @visible_tabs and @current_user.role in ["admin", "manager"]} id={"bookmark-feed-#{bm.id}"} phx-click="bookmark_to_feed" phx-value-id={bm.id} class="btn btn-ghost btn-sm mt-2">Akışa ekle</button>
                      <%= if bm.note do %>
                        <p class="text-xs opacity-50 mt-2">{bm.note}</p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                  <div id="bookmarks-empty" class="hidden only:block col-span-full text-center opacity-50 py-10">
                    Henüz bookmark yok. "+ Yeni Bookmark" ile ekleyin.
                  </div>
              </div>
            <% :secrets -> %>
              <div class="flex justify-end mb-4">
                <.link id="open-infisical" navigate={~p"/admin/infisical"} class="btn btn-outline mr-2">Infisical</.link>
                <button :if={@current_user.role in ["admin", "manager"]} id="add-secret" class="btn btn-primary btn-sm" phx-click="open_secret_modal" disabled={@vault_locked}>+ Yeni Secret</button>
              </div>
              <div id="secret-cards" phx-update="stream" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div :for={{dom_id, s} <- @streams.secret_cards} id={dom_id} class="card bg-base-100 border border-base-300">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base">{s.title}</h3>
                    <p :if={s.url} class="text-xs opacity-60 break-all">{s.url}</p>
                    <div class="card-actions mt-2">
                      <button id={"reveal-secret-#{s.id}"} phx-click="toggle_secret" phx-value-id={s.id} disabled={@vault_locked} class="btn btn-sm btn-outline">Erişim bilgileri</button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"edit-secret-#{s.id}"} phx-click="open_secret_modal" phx-value-id={s.id} disabled={@vault_locked} class="btn btn-sm btn-ghost">Düzenle</button>
                      <button :if={@current_user.role in ["admin", "manager"]} id={"delete-secret-#{s.id}"} phx-click="delete_secret" phx-value-id={s.id} disabled={@vault_locked} data-confirm="Kasa kaydı silinsin mi? Araç bağlantıları kaldırılır." class="btn btn-sm btn-ghost text-error">Sil</button>
                    </div>
                  </div>
                </div>
                <p id="secrets-empty" class="hidden only:block col-span-full text-center opacity-60 py-10">Henüz kasa kaydı yok. Kasayı açıp yeni kayıt ekleyebilirsin.</p>
              </div>
            <% :activity -> %>
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-lg font-semibold">Aktivite (Sap)</h2>
                <button class="btn btn-sm btn-outline" phx-click="refresh">Yenile</button>
              </div>
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div class="card bg-base-100">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base mb-2">🔐 Erişim Logları</h3>
                    <div class="overflow-x-auto">
                      <table class="table table-zebra table-sm">
                        <thead>
                          <tr>
                            <th>Zaman</th>
                            <th>Kullanıcı</th>
                            <th>Nesne</th>
                            <th>İşlem</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for l <- @access_logs do %>
                            <tr>
                              <td class="text-xs opacity-70">{l.accessed_at}</td>
                              <td class="text-xs">{l.user_id}</td>
                              <td class="text-xs">
                                {(l.secret_id && "secret") || (l.note_id && "note") || "panel"}
                              </td>
                              <td class="text-xs">erişim</td>
                            </tr>
                          <% end %>
                          <%= if Enum.empty?(@access_logs) do %>
                            <tr>
                              <td colspan="4" class="text-center opacity-50 py-4">
                                Henüz erişim kaydı yok
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <div class="card bg-base-100">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base mb-2">🆔 NPM Activity</h3>
                    <div class="overflow-x-auto">
                      <table class="table table-zebra table-sm">
                        <thead>
                          <tr>
                            <th>Zaman</th>
                            <th>Nesne</th>
                            <th>İşlem</th>
                            <th>Actor</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for l <- @npm_audit_logs do %>
                            <tr>
                              <td class="text-xs opacity-70">{l.time}</td>
                              <td class="text-xs">{l.object}</td>
                              <td class="text-xs">{l.action}</td>
                              <td class="text-xs opacity-70">{l.actor}</td>
                            </tr>
                          <% end %>
                          <%= if Enum.empty?(@npm_audit_logs) do %>
                            <tr>
                              <td colspan="4" class="text-center opacity-50 py-4">
                                NPM audit kaydı yok
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>
            <% :settings -> %>
              <div class="max-w-lg space-y-4">
                <div class="alert alert-info">Panel ayarları buradan yönetilecek (yakında).</div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Tools</div>
                  <div class="stat-value">{@tools_count}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Bookmarks</div>
                  <div class="stat-value">{@bookmarks_count}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Secrets</div>
                  <div class="stat-value">{@secrets_count}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Access Logs</div>
                  <div class="stat-value">{length(@access_logs)}</div>
                </div>
              </div>
          <% end %>
          
    <!-- Modals -->
          <%= if @modal == :read_note and @selected_note do %>
            <dialog id="note-reader" class="modal modal-open" aria-labelledby="note-reader-title">
              <div class="modal-box max-w-3xl">
                <h2 id="note-reader-title" class="text-xl font-semibold mb-5">{@selected_note.title}</h2>
                <pre id="note-markdown" class="whitespace-pre-wrap break-words font-mono text-sm leading-relaxed">{@selected_note.body}</pre>
                <div class="modal-action">
                  <button id="export-note" phx-click="export_note" phx-value-id={@selected_note.id} data-confirm="Not şifrelenmemiş bir .md dosyası olarak indirilecek. Devam edilsin mi?" class="btn btn-outline">.md indir</button>
                  <button phx-click="close_modal" class="btn">Kapat</button>
                </div>
              </div>
            </dialog>
          <% end %>

          <%= if @modal == :feed do %>
            <dialog id="feed-dialog" class="modal modal-open" aria-labelledby="feed-form-title">
              <div class="modal-box">
                <h2 id="feed-form-title" class="text-lg font-semibold mb-4">Akışa ekle</h2>
                <.form for={@feed_form} id="feed-form" phx-submit="save_feed" phx-change="validate_feed">
                  <.input field={@feed_form[:kind]} type="select" label="İçerik türü" options={Enum.map(PrivateFeed.Entry.kinds(), &{feed_kind(&1), &1})} />
                  <.input field={@feed_form[:title]} label="Başlık" required />
                  <.input field={@feed_form[:body]} type="textarea" label="Yazın veya yorumun" rows="4" />
                  <.input field={@feed_form[:url]} type="url" label="Kaynak bağlantısı" />
                  <.input field={@feed_form[:owner]} label="Sahip · ilk etiket" placeholder="Kişi, şirket veya marka" required />
                  <.input field={@feed_form[:publisher_text]} label="Yayıncılar · sonraki etiketler" placeholder="Virgülle ayır: şirket sitesi, X hesabım" />
                  <.input field={@feed_form[:topic_text]} label="Konu etiketleri" placeholder="teknoloji, müzik" />
                  <p class="text-xs opacity-60">Yalnızca kapalı akışa kaydedilir. Dış yayın için kanal bağlantıları henüz kurulmadı.</p>
                  <div class="modal-action"><button type="button" phx-click="close_modal" class="btn">İptal</button><button type="submit" class="btn btn-primary">Akışa ekle</button></div>
                </.form>
              </div>
            </dialog>
          <% end %>

          <%= if @modal == :bookmark do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Bookmark'ı Düzenle", else: "Yeni Bookmark"}
                </h3>
                <.form for={@bookmark_form} id="bookmark-form" phx-submit="save_bookmark" phx-change="validate_bookmark">
                  <.input field={@bookmark_form[:title]} label="Başlık" required />
                  <.input field={@bookmark_form[:url]} label="URL" type="url" required />
                  <.input field={@bookmark_form[:category]} label="Kategori" />
                  <.input field={@bookmark_form[:note]} label="Not" type="textarea" />
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :note do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Notu Düzenle", else: "Yeni Not"}
                </h3>
                <.form for={@note_form} id="note-form" phx-submit="save_note" phx-change="validate_note">
                  <.input field={@note_form[:title]} label="Başlık" required />
                  <.input field={@note_form[:body]} label="Markdown içeriği" type="textarea" rows="12" class="textarea textarea-bordered w-full font-mono text-sm leading-relaxed" />
                  <p class="text-xs opacity-60">Bu kayıt şifreli saklanır ve yalnızca kasa açıkken okunabilir.</p>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :tool do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Aracı Düzenle", else: "Yeni Araç"}
                </h3>
                <.form for={@tool_form} id="tool-form" phx-submit="save_tool" phx-change="validate_tool">
                  <.input field={@tool_form[:name]} label="Ad" required />
                  <.input field={@tool_form[:url]} label="URL" type="url" />
                  <.input field={@tool_form[:description]} label="Ne için kullanılıyor?" type="textarea" />
                  <.input field={@tool_form[:identity]} label="Şirket / proje" placeholder="Örn. Harezm veya kişisel" />
                  <.input field={@tool_form[:category]} label="Kategori" />
                  <.input :if={:secrets in @visible_tabs} field={@tool_form[:secret_id]} type="select" label="Kasadaki erişim kaydı" prompt="Kasa kaydı bağlama" options={@secret_options} />
                  <p class="text-xs opacity-60">Şifreler kasada kalır. Buraya yalnızca aracın adresini yaz.</p>
                  <label class="label cursor-pointer justify-start gap-2 mt-2">
                    <.input
                      field={@tool_form[:is_active]}
                      type="checkbox"
                      class="checkbox checkbox-success"
                    />
                    <span class="label-text">Aktif</span>
                  </label>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :secret do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Secret'ı Düzenle", else: "Yeni Secret"}
                </h3>
                <.form for={@secret_form} id="secret-form" phx-submit="save_secret" phx-change="validate_secret">
                  <.input field={@secret_form[:title]} label="Başlık" required />
                  <.input field={@secret_form[:username]} label="Kullanıcı Adı" />
                  <.input field={@secret_form[:password]} label="Şifre" type="password" />
                  <.input field={@secret_form[:url]} label="URL" type="url" />
                  <.input field={@secret_form[:notes]} label="Notlar" type="textarea" />
                  <p class="text-xs opacity-60">Bu kayıt şifreli saklanır ve yalnızca kasa açıkken okunabilir.</p>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :credential and @selected_secret do %>
            <dialog id="credential-dialog" class="modal modal-open" aria-labelledby="credential-title">
              <div class="modal-box">
                <h2 id="credential-title" class="text-lg font-semibold mb-4">{@selected_secret.title}</h2>
                <p class="text-xs opacity-60 mb-4">Bu erişim kaydedildi. İşin bitince kasayı kilitle.</p>
                <div class="space-y-3">
                  <label class="block text-sm">Kullanıcı adı
                    <input id="credential-username" class="input input-bordered w-full mt-1" value={@selected_secret.username} readonly />
                  </label>
                  <button id="copy-username" phx-click="copy_secret" phx-value-id={@selected_secret.id} phx-value-field="username" class="btn btn-sm btn-outline">Kullanıcı adını kopyala</button>
                  <label class="block text-sm">Şifre
                    <input id="credential-password" class="input input-bordered w-full mt-1 font-mono" value={@selected_secret.password} readonly autocomplete="off" />
                  </label>
                  <button id="copy-password" phx-click="copy_secret" phx-value-id={@selected_secret.id} phx-value-field="password" class="btn btn-sm btn-outline">Şifreyi kopyala</button>
                  <p id="clipboard-status" role="status" class="text-sm"></p>
                </div>
                <div class="modal-action">
                  <button id="credential-close" phx-click="close_modal" class="btn">Kapat</button>
                  <button phx-click="lock_vault" class="btn btn-primary">Kasayı kilitle</button>
                </div>
              </div>
            </dialog>
          <% end %>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # Every websocket event is authorized independently of menu visibility.
  defp authorize_event(event, params, socket) do
    previous = socket.assigns.current_user
    user = Accounts.get_user(previous.id)

    cond do
      is_nil(user) ->
        {:halt, socket |> lock_vault() |> push_navigate(to: ~p"/login")}
      user.role != previous.role or user.allowed_tabs != previous.allowed_tabs or
          user.hashed_password != previous.hashed_password ->
        {:halt, socket |> lock_vault() |> push_navigate(to: ~p"/admin")}
      true ->
        socket = if vault_expired?(socket), do: lock_vault(socket), else: socket

        if event_allowed?(event, params, socket) do
          {:cont, socket}
        else
          {:halt, put_flash(socket, :error, "Bu işlem için yetki veya açık kasa gerekli.")}
        end
    end
  end

  defp event_allowed?(event, params, socket) do
    tabs = socket.assigns.visible_tabs
    writer? = socket.assigns.current_user.role in ["admin", "manager"]
    resources = [{"tool", :tools, Panel.Tool}, {"bookmark", :bookmarks, Panel.Bookmark},
      {"note", :notes, Notebook.Note}, {"secret", :secrets, Panel.Secret}]

    resource = Enum.find(resources, fn {name, _, _} ->
      event in ["open_#{name}_modal", "validate_#{name}", "save_#{name}", "delete_#{name}"]
    end)

    cond do
      resource != nil ->
        {name, tab, schema} = resource
        writer? and tab in tabs and
          (tab not in [:notes, :secrets] or not socket.assigns.vault_locked) and
          valid_resource_event?(event, name, schema, params, socket) and
          allowed_credential_link?(name, params, socket)
      event in ["read_note", "export_note"] ->
        :notes in tabs and not socket.assigns.vault_locked and valid_id?(params["id"])
      event in ["validate_markdown_import", "import_markdown"] ->
        writer? and :notes in tabs and not socket.assigns.vault_locked
      event in ["open_feed_modal", "delete_feed", "validate_feed", "save_feed"] ->
        writer? and :feed in tabs and
          (event not in ["validate_feed", "save_feed"] or socket.assigns.modal == :feed) and
          (event != "delete_feed" or valid_id?(params["id"]))
      event == "bookmark_to_feed" ->
        writer? and :feed in tabs and :bookmarks in tabs and valid_id?(params["id"])
      event == "load_more_feed" -> :feed in tabs and socket.assigns.feed_more
      event == "open_tool_template" ->
        writer? and :tools in tabs and params["template"] in ["activepieces", "windmill"]
      event in ["toggle_secret", "copy_secret"] ->
        :secrets in tabs and not socket.assigns.vault_locked and valid_id?(params["id"])
      event == "show_tool_secret" ->
        :tools in tabs and :secrets in tabs and not socket.assigns.vault_locked and valid_id?(params["id"])
      event == "unlock_vault" -> :notes in tabs or :secrets in tabs
      event in ["toggle_user_perms", "update_user_role", "save_user_perms", "refresh"] ->
        socket.assigns.current_user.role == "admin"
      event in ["search", "nav", "toggle_sidebar", "close_modal", "lock_vault", "lv:clear-flash"] -> true
      true -> false
    end
  end

  defp valid_resource_event?(event, name, schema, params, socket) do
    cond do
      event in ["save_#{name}", "validate_#{name}"] ->
        socket.assigns.modal == resource_modal(name) and
          (is_nil(socket.assigns.editing) or is_struct(socket.assigns.editing, schema))
      Map.has_key?(params, "id") ->
        valid_id?(params["id"]) and not is_nil(resource_record(name, params["id"]))
      event == "open_#{name}_modal" -> true
      true -> false
    end
  end

  defp resource_record("tool", id), do: Panel.get_tool(id)
  defp resource_record("bookmark", id), do: Panel.get_bookmark(id)
  defp resource_record("note", id), do: Notebook.get(id)
  defp resource_record("secret", id), do: Panel.get_secret(id)

  defp resource_modal("tool"), do: :tool
  defp resource_modal("bookmark"), do: :bookmark
  defp resource_modal("note"), do: :note
  defp resource_modal("secret"), do: :secret

  defp valid_id?(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} when value > 0 and value <= 9_223_372_036_854_775_807 -> true
      _ -> false
    end
  end
  defp valid_id?(id), do: is_integer(id) and id > 0

  defp allowed_credential_link?("tool", %{"tool" => attrs}, socket) do
    current = case socket.assigns.editing do
      %Panel.Tool{secret_id: id} -> id
      _ -> nil
    end

    not Map.has_key?(attrs, "secret_id") or
      to_string(attrs["secret_id"] || "") == to_string(current || "") or
      :secrets in socket.assigns.visible_tabs
  end
  defp allowed_credential_link?(_, _, _), do: true

  defp reveal_secret(socket, id) do
    with %Panel.Secret{} = secret <- Panel.get_secret(id),
         {:ok, _} <- Panel.log_access(socket.assigns.current_user.id, :secret, secret.id, nil) do
      {:noreply, assign(socket, selected_secret: secret, modal: :credential)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Kasa kaydı açılamadı.")}
    end
  end

  defp vault_expired?(socket) do
    expires = socket.assigns.vault_expires_at
    is_integer(expires) and System.monotonic_time(:millisecond) >= expires
  end

  defp lock_vault(socket) do
    assign(socket, vault_locked: true, vault_expires_at: nil, selected_secret: nil, selected_note: nil,
      modal: nil, editing: nil, secret_form: to_form(%{}), note_form: to_form(%{}),
      vault_password: to_form(%{}))
  end

  def handle_info({:lock_vault, expires}, socket) do
    if socket.assigns.vault_expires_at == expires do
      {:noreply, lock_vault(socket)}
    else
      {:noreply, socket}
    end
  end

  defp maybe_load_feed(socket, :feed) do
    page = PrivateFeed.page()
    socket |> assign(feed_more: page.more?, feed_cursor: page.cursor)
      |> stream(:feed_entries, page.entries, reset: true)
  end
  defp maybe_load_feed(socket, _tab), do: socket

  defp load_collection(socket, tab) when tab in [:tools, :bookmarks, :notes, :secrets] do
    {stream_name, count_name, rows} = case tab do
      :tools -> {:tool_cards, :tools_count, if(tab in socket.assigns.visible_tabs, do: Panel.list_tools(), else: [])}
      :bookmarks -> {:bookmark_cards, :bookmarks_count, if(tab in socket.assigns.visible_tabs, do: Panel.list_bookmarks(), else: [])}
      :notes -> {:note_cards, :notes_count, if(tab in socket.assigns.visible_tabs, do: Notebook.summaries(), else: [])}
      :secrets -> {:secret_cards, :secrets_count, if(tab in socket.assigns.visible_tabs, do: Panel.list_secret_summaries(), else: [])}
    end
    socket = if tab == :secrets, do: assign(socket, :secret_options, Enum.map(rows, &{&1.title, &1.id})), else: socket
    socket |> assign(count_name, length(rows)) |> stream(stream_name, rows, reset: true)
  end
  defp load_collection(socket, _tab), do: socket

  defp feed_kind(kind) do
    %{ "post" => "Yazı", "blog" => "Blog", "news" => "Haber", "video" => "Video",
       "music" => "Müzik", "bookmark" => "Bookmark" }[kind] || kind
  end

  # --- Helpers --------------------------------------------------------------
  defp visible_tabs_for(%{role: "admin"}), do: Keyword.keys(@tabs)
  defp visible_tabs_for(%{role: "manager"} = user), do: visible_tabs_from_allowed(user)
  defp visible_tabs_for(%{role: "viewer"} = user), do: visible_tabs_from_allowed(user)

  defp visible_tabs_for(_), do: [:dashboard]

  # Accounts.allowed_tabs_for string list döner -> atomlara çevir ve @tabs'ta
  # olmayanları ele. Admin için Accounts zaten tüm tabları döndürür.
  defp visible_tabs_from_allowed(user) do
    allowed =
      case Accounts.allowed_tabs_for(user) do
        :all -> Keyword.keys(@tabs)
        tabs when is_list(tabs) -> Enum.filter(Keyword.keys(@tabs), &(Atom.to_string(&1) in tabs))
        _ -> []
      end

    (allowed ++ @default_viewer_tabs)
    |> Enum.uniq()
    |> Enum.filter(&(&1 in Keyword.keys(@tabs)))
  end

  defp active(tab, tab), do: "active"
  defp active(_current, _tab), do: ""
end
