# tests the dag
defmodule TestDag do
  use ExUnit.Case
  doctest Blxx.Dag

  test "open_vstore" do
    filepath =
      "~/scratch/" <> (Blxx.Util.utc_stamp() |> to_string()) <> ".dets"
      |> Path.expand()
      |> to_charlist()
    IO.inspect filepath
    {:ok, {d, g}} = Blxx.Dag.open_store(filepath)
    assert :digraph.vertices(g) == [:root]
    assert :digraph.edges(g) == []
    assert {:ok, _} = Blxx.Dag.clean_nodes(d)
    assert :ok == Blxx.Dag.close_store(d)
  end

end
