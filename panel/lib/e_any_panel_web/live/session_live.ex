defmodule EAnyPanelWeb.SessionLive do
  use EAnyPanelWeb, :live_view

  alias EAnyPanel.Accounts

  def mount(_params, session, socket) do
    # A viewer-only scope is enough for the login screen.
    socket =
      socket
      |> assign(:current_scope, %{})
      |> assign(:error, nil)
      |> assign(:setup_needed?, Accounts.setup_needed?())
      |> assign(:form, to_form(%{"email" => "", "password" => ""}))
      |> assign(:token, nil)

    # The TOTP step arrives via /login/totp?token=X — keep the token so the
    # verify handler can finalize the session.
    case session do
      %{"token" => token} -> {:ok, assign(socket, :token, token)}
      _ -> {:ok, socket}
    end
  end

  def render(%{live_action: :new} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-md">
        <h1 class="text-2xl font-semibold mb-6">Giriş yap</h1>

        <%= if @setup_needed? do %>
          <div class="alert alert-warning mb-4">
            <span>First-time setup: create an admin with</span>
            <code class="ml-2">mix e_any_panel.create_admin you@e-any.online password</code>
          </div>
        <% end %>

        <.form for={@form} id="login-form" phx-submit="login">
          <.input field={@form[:email]} type="email" label="E-posta" autocomplete="username" required />
          <.input field={@form[:password]} type="password" label="Şifre" autocomplete="current-password" required />
          <div class="mt-4">
            <button type="submit" class="btn btn-primary">Giriş yap</button>
          </div>
        </.form>

        <%= if @error do %>
          <p class="mt-2 text-error">{@error}</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def render(%{live_action: :totp} = assigns) do
    form = to_form(%{"code" => ""})

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-md">
        <h1 class="text-2xl font-semibold mb-6">İki adımlı doğrulama</h1>
        <p>Doğrulama uygulamandaki kodu gir.</p>

        <.form for={form} id="totp-form" phx-submit="verify_totp">
          <.input field={form[:code]} type="text" label="Doğrulama kodu" autocomplete="one-time-code" inputmode="numeric" required />
          <.input type="hidden" name="token" value={@token} />
          <div class="mt-4">
            <button type="submit" class="btn btn-primary">Doğrula</button>
          </div>
        </.form>

        <%= if @error do %>
          <p class="mt-2 text-error">{@error}</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("login", %{"email" => email, "password" => password}, socket) do
    require Logger
    Logger.warning("LOGIN_ATTEMPT email=#{inspect(email)} pw_len=#{String.length(password)}")

    case Accounts.authenticate_by_email_and_password(email, password) do
      {:ok, user} ->
        Logger.warning("LOGIN_OK user_id=#{user.id}")
        # Password valid. If the user has a TOTP secret we must complete 2FA
        # before writing the session; otherwise single-factor is enough.
        token = Phoenix.Token.sign(EAnyPanelWeb.Endpoint, "login", user.id)

        {:noreply,
         if user.totp_secret do
           # Hand off to the TOTP LiveView (controller keeps session unwritten).
           socket
           |> put_flash(:info, "Password accepted. Enter your 2FA code.")
           |> push_navigate(to: ~p"/session/create?token=#{token}&step=totp")
         else
           # No 2FA configured: finalize directly.
           socket
           |> put_flash(:info, "Welcome back, #{user.email}")
           |> push_navigate(to: ~p"/session/create?token=#{token}")
         end}

      :error ->
        form = to_form(%{"email" => email, "password" => ""})

        {:noreply, assign(socket, form: form, error: "Invalid email or password")}
    end
  end

  @impl true
  def handle_event("verify_totp", %{"code" => code, "token" => token}, socket) do
    case Phoenix.Token.verify(EAnyPanelWeb.Endpoint, "login", token, max_age: 120) do
      {:ok, user_id} ->
        user = Accounts.get_user(user_id)

        if user && Accounts.verify_totp(user.totp_secret, code) do
          # 2FA verified: finalize the session.
          {:noreply,
           socket
           |> put_flash(:info, "Welcome back, #{user.email}")
           |> push_navigate(to: ~p"/session/create?token=#{token}")}
        else
          {:noreply, assign(socket, error: "Invalid TOTP code")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Session expired, please log in again.")
         |> push_navigate(to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("logout", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/logout")}
  end
end
