defmodule EAnyPanel.ToolCatalogTest do
  use ExUnit.Case, async: true

  alias EAnyPanel.Release

  @fixture Path.expand("../support/fixtures/tool_catalog_example.exs", __DIR__)

  test "valid catalog yields one valid changeset per entry" do
    changesets = Release.read_tool_catalog!(@fixture)
    assert length(changesets) == 2
    assert Enum.all?(changesets, & &1.valid?)
  end

  test "rejects duplicate URLs and credential-bearing URLs" do
    path = Path.join(System.tmp_dir!(), "bad_catalog_#{System.unique_integer([:positive])}.exs")

    File.write!(path, ~s([%{name: "a", url: "https://x.test"}, %{name: "b", url: "https://x.test"}]))
    assert_raise ArgumentError, ~r/duplicate/, fn -> Release.read_tool_catalog!(path) end

    File.write!(path, ~s([%{name: "a", url: "https://user:pw@x.test"}]))
    assert_raise ArgumentError, ~r/invalid tool/, fn -> Release.read_tool_catalog!(path) end
  end
end
