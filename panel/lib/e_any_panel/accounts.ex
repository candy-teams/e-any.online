defmodule EAnyPanel.Accounts do
  @moduledoc """
  Account / authentication context. Closed registration: only an admin can be
  created (via `mix e_any_panel.create_admin`). No public sign-up.
  """
  import Ecto.Query, warn: false
  alias EAnyPanel.Repo
  alias EAnyPanel.Accounts.User

  def list_users, do: Repo.all(User)

  # Role / permissions

  @roles ~w(admin manager viewer)

  @all_tabs ~w(dashboard feed bookmarks notes tools secrets landing proxy_hosts access_lists certificates users audit_logs activity settings panel)

  def roles, do: @roles
  def all_tabs, do: @all_tabs

  @doc "Role'a göre erişilebilir sekmeler. admin her şeyi görür, diğerleri sadece allowed_tabs'takileri."
  def allowed_tabs_for(%User{} = user) do
    cond do
      user.role == "admin" -> @all_tabs
      is_binary(user.allowed_tabs) and user.allowed_tabs != "" ->
        case Jason.decode(user.allowed_tabs) do
          {:ok, tabs} when is_list(tabs) -> tabs
          _ -> []
        end
      true -> []
    end
  end

  @doc "Kullanıcı belirli bir sekmeye erişebilir mi?"
  def can_access_tab?(%User{role: "admin"}, _tab), do: true
  def can_access_tab?(%User{}, "dashboard"), do: true
  def can_access_tab?(%User{} = user, tab) do
    tab in allowed_tabs_for(user)
  end

  @doc "Update user role + allowed tabs (admin only)."
  def update_user_roles(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:role, :allowed_tabs])
    |> Ecto.Changeset.validate_inclusion(:role, @roles)
    |> case do
      %Ecto.Changeset{valid?: true} = cs -> Repo.update(cs)
      cs -> {:error, cs}
    end
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)
  def get_user_by_email(_), do: nil

  def get_user_by_email!(email), do: Repo.get_by!(User, email: email)

  @doc "Bang variant of `create_user/1` for tests/setup scripts."
  def create_user!(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert!()
  end

  @doc "Set or rotate the user's TOTP secret (used by 2FA enrollment)."
  def update_user_totp_secret(user, secret) when is_binary(secret) do
    user
    |> User.changeset(%{totp_secret: secret})
    |> Repo.update()
  end

  @doc "Create an admin user. Password is hashed with Argon2."
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Authenticate by email + password. Returns `{:ok, user}` or `:error`."
  def authenticate_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    with user when not is_nil(user) <- get_user_by_email(email),
         true <- Argon2.verify_pass(password, user.hashed_password) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  def authenticate_by_email_and_password(_, _), do: :error

  @doc "Re-verify the password for an already-known user (vault re-auth)."
  def verify_password(user, password) when is_binary(password) do
    if Argon2.verify_pass(password, user.hashed_password), do: :ok, else: :error
  end

  @doc "Verify a TOTP code against the user's binary secret."
  def verify_totp(nil, _code), do: false

  def verify_totp(secret, code) when is_binary(secret) and is_binary(code) do
    NimbleTOTP.valid?(secret, code, interval: 30, grace: 1)
  end

  def totp_provisioning_uri(user, label \\ "e-any-panel") do
    if user.totp_secret do
      NimbleTOTP.otpauth_uri("#{label}:#{user.email}", user.totp_secret)
    else
      nil
    end
  end

  @doc "Number of existing users (used to decide if setup is needed)."
  def user_count, do: Repo.aggregate(User, :count)

  def setup_needed?, do: user_count() == 0
end
