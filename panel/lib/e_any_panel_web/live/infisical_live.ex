defmodule EAnyPanelWeb.InfisicalLive do
  use EAnyPanelWeb, :live_view
  alias EAnyPanel.{Accounts, Infisical, InfisicalAccess}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Accounts.can_access_tab?(user, "secrets") do
      if connected?(socket), do: Process.send_after(self(), :check_access, 5_000)

      {:ok,
       socket
       |> assign(
         page_title: "Infisical",
         configured: Infisical.configured?(),
         expires: nil,
         fingerprint: user.hashed_password,
         revealed: nil,
         reveal_ref: nil,
         writable: user.role in ["admin", "manager"],
         loaded: false,
         write_revision: 0,
         unlock_form: to_form(%{}, as: :unlock),
         write_form: blank_form()
       )
       |> stream(:credentials, [])}
    else
      {:ok, redirect(socket, to: ~p"/admin")}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case refresh_access(socket) do
      {:denied, socket} -> {:noreply, redirect(socket, to: ~p"/login")}
      {:ok, socket} -> dispatch(event, params, socket)
    end
  end

  defp dispatch("unlock", %{"unlock" => %{"password" => password}}, socket)
       when is_binary(password) do
    user = socket.assigns.current_user

    with {:allow, _} <- Hammer.check_rate("vault-unlock:#{user.id}", 60_000, 5),
         :ok <- Accounts.verify_password(user, password) do
      {:noreply,
       socket
       |> assign(expires: now() + 300_000, unlock_form: to_form(%{}, as: :unlock))
       |> load()}
    else
      _ ->
        {:noreply,
         socket
         |> lock()
         |> put_flash(:error, "Kasa açılamadı. Parolanı kontrol et veya biraz bekle.")}
    end
  end

  defp dispatch("lock", _, socket), do: {:noreply, lock(socket)}
  defp dispatch("hide", _, socket), do: {:noreply, assign(socket, revealed: nil, reveal_ref: nil)}

  defp dispatch(event, params, socket) when event in ["reload", "read", "save"] do
    if socket.assigns.expires do
      perform(event, params, socket)
    else
      {:noreply, put_flash(lock(socket), :error, "Önce kasayı aç.")}
    end
  end

  defp dispatch(_, _, socket), do: {:noreply, socket}

  defp perform("reload", _, socket), do: {:noreply, load(socket)}

  defp perform("read", %{"name" => name}, socket) do
    socket = assign(socket, revealed: nil, reveal_ref: nil)

    case InfisicalAccess.run(socket.assigns.current_user.id, :read, name) do
      {:ok, value} ->
        ref = make_ref()
        Process.send_after(self(), {:hide, ref}, 60_000)
        {:noreply, assign(socket, revealed: %{name: name, value: value}, reveal_ref: ref)}

      {:error, reason} ->
        {:noreply, failure(socket, reason)}
    end
  end

  defp perform(
         "save",
         %{"credential" => %{"operation" => operation, "name" => name, "value" => value}},
         socket
       )
       when operation in ["create", "update"] do
    socket =
      assign(socket,
        write_form: blank_form(),
        revealed: nil,
        reveal_ref: nil,
        write_revision: socket.assigns.write_revision + 1
      )

    if socket.assigns.writable do
      action = if operation == "create", do: :create, else: :update

      case InfisicalAccess.run(socket.assigns.current_user.id, action, name, value) do
        :ok -> {:noreply, socket |> put_flash(:info, "Infisical kaydı kaydedildi.") |> load()}
        {:error, reason} -> {:noreply, failure(socket, reason)}
      end
    else
      {:noreply, failure(socket, :access_denied)}
    end
  end

  defp perform(_, _, socket), do: {:noreply, failure(socket, :invalid_input)}

  @impl true
  def handle_info(:check_access, socket) do
    Process.send_after(self(), :check_access, 5_000)

    case refresh_access(socket) do
      {:ok, socket} -> {:noreply, socket}
      {:denied, socket} -> {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_info({:hide, ref}, socket) do
    if socket.assigns.reveal_ref == ref do
      {:noreply, assign(socket, revealed: nil, reveal_ref: nil)}
    else
      {:noreply, socket}
    end
  end

  defp refresh_access(socket) do
    user = Accounts.get_user(socket.assigns.current_user.id)

    if user && Accounts.can_access_tab?(user, "secrets") do
      changed =
        user.hashed_password != socket.assigns.fingerprint or
          user.role != socket.assigns.current_user.role or
          user.allowed_tabs != socket.assigns.current_user.allowed_tabs

      expired = socket.assigns.expires && socket.assigns.expires <= now()
      socket = if changed or expired, do: lock(socket), else: socket

      {:ok,
       assign(socket,
         current_user: user,
         current_scope: %{user: user},
         fingerprint: user.hashed_password,
         writable: user.role in ["admin", "manager"]
       )}
    else
      {:denied, lock(socket)}
    end
  end

  defp load(socket) do
    case InfisicalAccess.run(socket.assigns.current_user.id, :list) do
      {:ok, rows} ->
        socket |> assign(loaded: true) |> stream(:credentials, rows, reset: true)

      {:error, reason} ->
        socket
        |> assign(loaded: false)
        |> stream(:credentials, [], reset: true)
        |> failure(reason)
    end
  end

  defp lock(socket) do
    socket
    |> assign(
      expires: nil,
      revealed: nil,
      reveal_ref: nil,
      loaded: false,
      write_form: blank_form()
    )
    |> stream(:credentials, [], reset: true)
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp blank_form,
    do: to_form(%{"operation" => "create", "name" => "", "value" => ""}, as: :credential)

  defp failure(socket, reason) do
    message =
      case reason do
        :not_configured ->
          "Infisical bağlantısı henüz yapılandırılmadı."

        :access_denied ->
          "Bu işlem için yetkin yok."

        :invalid_input ->
          "Kayıt adı harf veya alt çizgiyle başlamalı; yalnızca harf, rakam, alt çizgi ve tire kullan. Değer boş olamaz."

        :not_found ->
          "Kayıt bulunamadı."

        :conflict ->
          "Bu ad zaten kullanılıyor."

        :unconfirmed_write ->
          "Kaydetme sonucu doğrulanamadı. Tekrar göndermeden önce kaydı kontrol et."

        _ ->
          "Infisical işlemi tamamlanamadı. Bağlantı ve erişim ayarlarını kontrol et."
      end

    put_flash(socket, :error, message)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="max-w-3xl mx-auto p-4 space-y-6" id="infisical-vault">
        <.link navigate={~p"/admin?tab=secrets"} class="btn btn-ghost">Kasaya dön</.link>
        <header><h1 class="text-2xl font-semibold">Infisical</h1><p>Paylaşılan erişim bilgileri</p></header>
        <p :if={!@configured} id="infisical-setup" role="status">Bağlantı kurulmayı bekliyor. Sunucuda Infisical proje, ortam, klasör ve kimlik ayarları gerekli.</p>
        <.form :if={!@expires && @configured} for={@unlock_form} id="infisical-unlock" phx-submit="unlock" class="space-y-3">
          <.input field={@unlock_form[:password]} type="password" label="Panel parolan" autocomplete="current-password" required />
          <button class="btn btn-primary">5 dakika aç</button>
        </.form>
        <section :if={@expires} class="space-y-4">
          <div class="flex gap-2">
            <button id="infisical-reload" phx-click="reload" class="btn">Listeyi yenile</button>
            <button id="infisical-lock" phx-click="lock" class="btn">Kilitle</button>
          </div>
          <div id="infisical-records" phx-update="stream" class="divide-y divide-base-300">
            <div :for={{id, item} <- @streams.credentials} id={id} class="flex items-center justify-between gap-3 py-3">
              <span class="break-all">{item.name}</span>
              <button id={"read-#{item.name}"} phx-click="read" phx-value-name={item.name} class="btn">Göster</button>
            </div>
            <p id="infisical-empty" class="hidden only:block py-4">{if @loaded, do: "Bu klasörde kayıt yok.", else: "Liste henüz alınamadı."}</p>
          </div>
          <section :if={@revealed} id="infisical-revealed" class="border border-base-300 p-4 space-y-3">
            <h2>{@revealed.name}</h2>
            <pre id="infisical-value" class="whitespace-pre-wrap break-all select-all">{@revealed.value}</pre>
            <p>60 saniye sonra gizlenir.</p>
            <button id="infisical-hide" phx-click="hide" class="btn">Gizle</button>
          </section>
          <.form :if={@writable} for={@write_form} id={"infisical-write-#{@write_revision}"} phx-submit="save" class="space-y-3 border-t border-base-300 pt-4">
            <h2 class="text-lg font-semibold">Kayıt yaz</h2>
            <.input field={@write_form[:operation]} type="select" label="İşlem" options={[{"Yeni kayıt", "create"}, {"Mevcut değeri değiştir", "update"}]} />
            <.input field={@write_form[:name]} label="Kayıt adı" maxlength="128" required />
            <.input field={@write_form[:value]} type="password" label="Yeni değer" autocomplete="new-password" required />
            <button class="btn btn-primary" data-confirm="Belirtilen Infisical kaydı yazılsın mı? Güncelleme mevcut değeri değiştirir." phx-disable-with="Kaydediliyor...">Kaydet</button>
          </.form>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
