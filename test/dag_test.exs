# tests the dag
defmodule TestDag do
  use ExUnit.Case
  doctest Blxx.Dag

  test "open_vstore" do
    filepath =
      "~/.config/blxx/"
      |> Path.expand()
      |> Path.join("vstore.dets")
      |> to_charlist()
    Blxx.Dag.open_vstore(filepath)
    Blxx.Dag.clean_vstore()
    Blxx.Dag.close_vstore()
    {:ok, graph} = Blxx.Dag.open_vstore()
    assert :digraph.vertices(graph) == [:root]
    assert :digraph.edges(graph) == []
  end

  test "add_vertices" do
    Blxx.Dag.open_vstore()
    Blxx.Dag.clean_vstore()
    Blxx.Dag.close_vstore()
    {:ok, graph} = Blxx.Dag.open_vstore()
    assert Blxx.Dag.store_vertex(graph, :a, :root) == {:ok, graph}
    assert Blxx.Dag.store_vertex(graph, :b, :root) == {:ok, graph}
    mystamp = 1234
    assert Blxx.Dag.store_vertex(graph, :c, :a, %{}, mystamp) == {:ok, graph}
    mymeta = %{desc: "test"}
    assert Blxx.Dag.store_vertex(graph, :d, :b, mymeta) == {:ok, graph}
  end

  test "add_duplicate_vertices_different_parents" do
    Blxx.Dag.open_vstore()
    Blxx.Dag.clean_vstore()
    Blxx.Dag.close_vstore()
    {:ok, graph} = Blxx.Dag.open_vstore()
    assert Blxx.Dag.store_vertex(graph, :a, :root) == {:ok, graph}
    assert Blxx.Dag.store_vertex(graph, :b, :root) == {:ok, graph}
    assert Blxx.Dag.store_vertex(graph, :c, :a) == {:ok, graph}
    assert Blxx.Dag.store_edge(graph, :c, :b) == {:ok, graph}
    assert Blxx.Dag.store_edge(graph, :c, :root) == {:ok, graph}
  end
end
