defmodule EAnyPanel.InfisicalTest do
  use ExUnit.Case, async: false
  alias EAnyPanel.Infisical

  setup do
    original = Application.get_env(:e_any_panel, Infisical)
    file = Path.join(System.tmp_dir!(), "infisical-test-#{System.unique_integer([:positive])}")
    File.write!(file, "test-token")

    Application.put_env(:e_any_panel, Infisical,
      base_url: "https://proxy.example.test",
      project_id: "test-project",
      environment: "dev",
      secret_path: "/agents",
      token_file: file
    )

    on_exit(fn ->
      File.rm(file)

      if original,
        do: Application.put_env(:e_any_panel, Infisical, original),
        else: Application.delete_env(:e_any_panel, Infisical)
    end)

    :ok
  end

  defp transport(fun) do
    Application.put_env(:e_any_panel, Infisical, Keyword.put(Infisical.config(), :transport, fun))
  end

  test "metadata lists request no values and strip unexpected sensitive fields" do
    transport(fn :get, url, headers, nil ->
      query = URI.decode_query(URI.parse(url).query)
      assert query["projectId"] == "test-project"
      assert query["environment"] == "dev"
      assert query["secretPath"] == "/agents"
      assert query["viewSecretValue"] == "false"
      assert query["includeImports"] == "false"
      assert query["recursive"] == "false"
      assert {"authorization", "Bearer test-token"} in headers

      {:ok, 200,
       Jason.encode!(%{
         secrets: [%{secretKey: "API_KEY", secretValue: "never-listed", version: 1}]
       })}
    end)

    assert {:ok, [%{id: "API_KEY", name: "API_KEY", version: 1}]} == Infisical.list()
  end

  test "invalid names cannot change the endpoint and hidden values are rejected" do
    transport(fn _, _, _, _ -> flunk("must not contact upstream") end)
    assert {:error, :invalid_input} = Infisical.read("../other")
    assert {:error, :invalid_input} = Infisical.write(:update, "A?secretPath=/", "x")

    transport(fn :get, _, _, _ ->
      {:ok, 200,
       Jason.encode!(%{secret: %{secretKey: "KEY", secretValue: "****", secretValueHidden: true}})}
    end)

    assert {:error, :invalid_response} = Infisical.read("KEY")
  end

  test "writes fix the destination and never retry ambiguous responses" do
    parent = self()

    transport(fn :patch, _, _, body ->
      send(parent, :write_attempt)

      assert Jason.decode!(body) == %{
               "projectId" => "test-project",
               "environment" => "dev",
               "secretPath" => "/agents",
               "type" => "shared",
               "secretValue" => "new-value"
             }

      {:error, :timeout}
    end)

    assert {:error, :unconfirmed_write} = Infisical.write(:update, "KEY", "new-value")
    assert_received :write_attempt
    refute_received :write_attempt
  end

  test "provider bodies and tokens are not returned on failure; token rotation is reread" do
    transport(fn _, _, headers, _ ->
      assert {"authorization", "Bearer rotated-test-token"} in headers
      {:ok, 403, "sensitive-provider-error"}
    end)

    File.write!(Infisical.config()[:token_file], "rotated-test-token")
    assert {:error, :access_denied} = Infisical.list()
    File.rm!(Infisical.config()[:token_file])
    assert {:error, :credentials_unavailable} = Infisical.list()
  end

  test "TLS is required except literal loopback; missing config disables access" do
    assert Infisical.valid_base?("http://127.0.0.1:8081")
    assert Infisical.valid_base?("https://proxy.example.test")
    refute Infisical.valid_base?("http://proxy.example.test")
    refute Infisical.valid_base?("https://user:password@proxy.example.test")
    refute Infisical.valid_base?("https://proxy.example.test/path")
    Application.put_env(:e_any_panel, Infisical, [])
    assert {:error, :not_configured} = Infisical.list()
  end
end
