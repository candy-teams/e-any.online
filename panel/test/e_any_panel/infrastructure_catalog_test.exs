defmodule EAnyPanel.InfrastructureCatalogTest do
  use ExUnit.Case, async: true

  alias EAnyPanel.Panel.Tool

  @path Path.expand("../../priv/repo/seeds/infrastructure_tools.exs", __DIR__)

  test "infrastructure catalog entries are valid, unique tools" do
    {tools, _} = Code.eval_file(@path)

    assert tools != []
    urls = Enum.map(tools, & &1.url)
    assert urls == Enum.uniq(urls)

    for attrs <- tools do
      changeset = Tool.changeset(%Tool{}, Map.put(attrs, :source, "internal"))
      assert changeset.valid?, "#{attrs.name}: #{inspect(changeset.errors)}"
    end
  end
end
