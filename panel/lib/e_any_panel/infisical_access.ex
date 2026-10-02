defmodule EAnyPanel.InfisicalAccess do
  @moduledoc "Internal authenticated UI boundary. The caller must enforce vault re-authentication."
  alias EAnyPanel.{Accounts, Infisical, InfisicalAudit, Repo}

  def run(user_id, operation, name \\ nil, value \\ nil)
      when operation in [:list, :read, :create, :update] do
    user = Accounts.get_user(user_id)

    allowed =
      user && Accounts.can_access_tab?(user, "secrets") &&
        (operation in [:list, :read] or user.role in ["admin", "manager"])

    if allowed do
      audited(user.id, operation, name, fn ->
        case operation do
          :list -> Infisical.list()
          :read -> Infisical.read(name)
          action -> Infisical.write(action, name, value)
        end
      end)
    else
      {:error, :access_denied}
    end
  end

  defp audited(user_id, operation, name, fun) do
    row = %InfisicalAudit{
      user_id: user_id,
      operation: Atom.to_string(operation),
      secret_name: if(Infisical.valid_name?(name), do: name),
      outcome: "attempt"
    }

    # Persist the attempt before contacting the provider. An unfinished attempt
    # can mean a remote write succeeded; it must never be automatically retried.
    audit = Repo.insert!(row)
    result = fun.()

    outcome =
      case result do
        :ok -> "ok"
        {:ok, _} -> "ok"
        {:error, reason} -> Atom.to_string(reason)
      end

    audit |> Ecto.Changeset.change(outcome: outcome) |> Repo.update!()
    result
  rescue
    _ ->
      {:error,
       if(operation in [:create, :update], do: :unconfirmed_write, else: :audit_unavailable)}
  end
end
