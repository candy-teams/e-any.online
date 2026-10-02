defmodule EAnyPanel.Infisical do
  @moduledoc """
  Internal adapter for one operator-configured Infisical project/environment/folder.
  Callers enforce user authorization and auditing. Agents use their own Infisical
  identities directly, never this panel's token. No secret is persisted here.
  """

  def config, do: Application.get_env(:e_any_panel, __MODULE__, [])

  def configured? do
    cfg = config()

    Enum.all?([:base_url, :project_id, :environment, :secret_path, :token_file], fn key ->
      is_binary(cfg[key]) and cfg[key] != ""
    end) and valid_base?(cfg[:base_url]) and valid_path?(cfg[:secret_path])
  end

  def scope do
    Map.new(Keyword.take(config(), [:project_id, :environment, :secret_path]))
  end

  def list do
    query =
      Map.merge(scope_params(), %{
        "viewSecretValue" => "false",
        "expandSecretReferences" => "false",
        "recursive" => "false",
        "includeImports" => "false",
        "includePersonalOverrides" => "false"
      })

    with {:ok, %{"secrets" => secrets}} when is_list(secrets) <-
           request(:get, "/api/v4/secrets", query, nil) do
      # Whitelist fields even if an upstream version returns unexpected values.
      rows =
        for %{"secretKey" => key} = secret <- secrets,
            valid_name?(key),
            do: %{
              id: key,
              name: key,
              version: secret["version"]
            }

      {:ok, rows}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_response}
    end
  end

  def read(name) do
    if valid_name?(name) do
      query =
        Map.merge(scope_params(), %{
          "type" => "shared",
          "viewSecretValue" => "true",
          "expandSecretReferences" => "false",
          "includeImports" => "false"
        })

      with {:ok, %{"secret" => %{"secretKey" => ^name, "secretValue" => value} = secret}}
           when is_binary(value) and byte_size(value) <= 65_536 <-
             request(:get, "/api/v4/secrets/" <> name, query, nil),
           false <- secret["secretValueHidden"] == true do
        {:ok, value}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_response}
      end
    else
      {:error, :invalid_input}
    end
  end

  def write(operation, name, value) when operation in [:create, :update] do
    if valid_name?(name) and is_binary(value) and byte_size(value) in 1..65_536 do
      body = Map.merge(scope_params(), %{"type" => "shared", "secretValue" => value})
      method = if operation == :create, do: :post, else: :patch

      # Do not retry mutations: a timeout can mean the upstream write succeeded.
      case request(method, "/api/v4/secrets/" <> name, %{}, body) do
        {:ok, %{"secret" => %{"secretKey" => ^name}}} -> :ok
        {:ok, _} -> {:error, :unconfirmed_write}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :invalid_input}
    end
  end

  def valid_name?(name),
    do: is_binary(name) and Regex.match?(~r/\A[A-Za-z_][A-Za-z0-9_-]{0,127}\z/, name)

  def valid_base?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok,
       %URI{scheme: scheme, host: host, path: path, userinfo: nil, query: nil, fragment: nil}} ->
        is_binary(host) and host != "" and path in [nil, "", "/"] and
          (scheme == "https" or (scheme == "http" and host in ["127.0.0.1", "::1"]))

      _ ->
        false
    end
  end

  def valid_base?(_), do: false

  defp valid_path?(path) when is_binary(path) do
    String.starts_with?(path, "/") and byte_size(path) <= 512 and
      not Enum.any?(String.split(path, "/"), &(&1 in [".", ".."]))
  end

  defp valid_path?(_), do: false

  defp scope_params do
    cfg = config()

    %{
      "projectId" => cfg[:project_id],
      "environment" => cfg[:environment],
      "secretPath" => cfg[:secret_path]
    }
  end

  defp request(method, path, query, body) do
    if configured?() do
      with {:ok, token} <- File.read(config()[:token_file]),
           token = String.trim(token),
           true <- byte_size(token) in 1..16_384 and not String.contains?(token, ["\r", "\n"]),
           {:ok, encoded} <- encode(body) do
        url = String.trim_trailing(config()[:base_url], "/") <> path
        url = if map_size(query) == 0, do: url, else: url <> "?" <> URI.encode_query(query)
        headers = [{"authorization", "Bearer " <> token}, {"content-type", "application/json"}]
        transport = config()[:transport] || (&__MODULE__.http/4)

        case transport.(method, url, headers, encoded) do
          {:ok, status, response} when status in 200..299 ->
            case Jason.decode(response) do
              {:ok, json} -> {:ok, json}
              _ -> {:error, :invalid_response}
            end

          {:ok, status, _} when status in [401, 403] ->
            {:error, :access_denied}

          {:ok, 404, _} ->
            {:error, :not_found}

          {:ok, 409, _} ->
            {:error, :conflict}

          {:ok, 429, _} ->
            {:error, :rate_limited}

          _ ->
            {:error, if(method == :get, do: :unavailable, else: :unconfirmed_write)}
        end
      else
        _ -> {:error, :credentials_unavailable}
      end
    else
      {:error, :not_configured}
    end
  rescue
    # Never forward provider bodies, request structs or exception messages.
    _ -> {:error, if(method == :get, do: :unavailable, else: :unconfirmed_write)}
  end

  defp encode(nil), do: {:ok, nil}
  defp encode(body), do: Jason.encode(body)

  @doc false
  def http(method, url, headers, body) do
    case Finch.build(method, url, headers, body)
         |> Finch.request(Finch, receive_timeout: 8_000, pool_timeout: 2_000) do
      {:ok, %Finch.Response{status: status, body: response}} -> {:ok, status, response}
      _ -> {:error, :unavailable}
    end
  end
end
