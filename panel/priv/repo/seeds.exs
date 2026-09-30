# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     EAnyPanel.Repo.insert!(%EAnyPanel.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Infrastructure tool catalog. Inserts missing URLs only; existing tools
# (and their Kasa links or manual edits) are left untouched.
alias EAnyPanel.{Repo, Panel.Tool}

{tools, _} = Code.eval_file(Path.join(__DIR__, "seeds/infrastructure_tools.exs"))

for attrs <- tools do
  unless Repo.get_by(Tool, url: attrs.url) do
    %Tool{}
    |> Tool.changeset(Map.put(attrs, :source, "internal"))
    |> Repo.insert!()
  end
end
