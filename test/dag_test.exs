# tests the dag
defmodule TestDag do
  use ExUnit.Case
  doctest Blxx.Dag

  def fileman(
        name \\ (Blxx.Util.utc_stamp() |> to_string) <> ".dets",
        dir \\ "/tmp"
      ) do
    filepath =
      Path.join(dir, name)
      |> Path.expand()
      |> to_charlist()

    {:ok, {d, g}} = Blxx.Dag.open_store(filepath)
    {:ok, {d, g}, filepath}
  end


  test "open_vstore" do
    {:ok, {d, g}, f} = fileman()
    assert :digraph.vertices(g) == [:root]
    assert :digraph.edges(g) == []
    assert {:ok, _} = Blxx.Dag.clean_nodes(d)
    assert :ok == Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)
  end

  
  test "add_vertex" do
    {:ok, {d, g}, f} = fileman()
    {isokay, _x} = Blxx.Dag.add_vertedge({d, g}, :a)
    assert isokay == :ok
    {isokay, _x} = Blxx.Dag.add_vertedge({d, g}, :b)
    assert isokay == :ok
    {isokay, _x} = Blxx.Dag.add_vertedge({d, g}, :c)
    assert isokay == :ok
    {isokay, _x} = Blxx.Dag.add_edge({d, g}, :b, :c)
    assert isokay == :ok

    assert Enum.all?(
             Enum.map([:a, :b, :c, :root], fn v -> Enum.member?(:digraph.vertices(g), v) end)
           )

    assert :ok == Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)
  end

  test "make_fx" do
    {:ok, {d, g}, f} = fileman()

    {isokay, {d, g}} =
      Blxx.Dag.add_vertedge({d, g}, :fx, :root, %{:asset_class => "foreign exchange"})

    assert isokay == :ok

    currs = [
      :EURPLN,
      :EURCZK,
      :USDUSD,
      :USDGBP,
      :USDCHF,
      :USDJPY,
      :USDSEK,
      :USDDKK,
      :USDHUF,
      :USDRUB,
      :USDTRY,
      :USDMXN,
      :USDZAR,
      :USDBRL,
      :USDPLN,
      :USDCAD,
      :USDAUD,
      :USDSGD,
      :USDHKD,
      :USDCNY,
      :USDINR,
      :USDKRW,
      :USDIDR,
      :USDMYR,
      :USDTHB,
      :USDPHP,
      :USDCOP,
      :USDPEN,
      :USDCZK,
      :USDRON,
      :USDBGN
    ]

    {isokay, {_, _}} = 
      Blxx.Dag.add_vertedges({d, g}, 
        currs, :fx, 
        fn v -> %{ticker: to_string(v) <> " Curncy", source: :blp} end)
    assert isokay == :ok
    # check if edges are all there
    edgevs = Enum.map(:digraph.edges(g), fn e -> Blxx.Dag.edge_vertices(g, e) end)
    assert Enum.all?(Enum.map(currs, fn v -> Enum.member?(edgevs, {:fx, v}) end))
    # check if vertices are all there
    assert Enum.all?(Enum.map(currs, fn v -> Enum.member?(:digraph.vertices(g), v) end))
    # cleanup
    Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)
  end


  test "addedge" do
    {:ok, {d, g}, f} = fileman()
    Blxx.Dag.add_vertedge({d, g}, :a)
    Blxx.Dag.add_vertedge({d, g}, :b)
    Blxx.Dag.add_vertedge({d, g}, :c)
    Blxx.Dag.add_vertedge({d, g}, :d)
    Blxx.Dag.add_vertedge({d, g}, :e)
    {ok1, {_x, _y}} = Blxx.Dag.add_edge({d, g}, :a, :b)
    {ok2, {_x, _y}} = Blxx.Dag.add_edge({d, g}, :a, :c)
    {ok3, {_x, _y}} = Blxx.Dag.add_edge({d, g}, :c, :d)
    {ok4, {_x, _y}} = Blxx.Dag.add_edge({d, g}, :c, :e)
    {ok5, {_x, _y}} = Blxx.Dag.add_edge({d, g}, :d, :e)
    assert ok1 == :ok
    assert ok2 == :ok
    assert ok3 == :ok
    assert ok4 == :ok
    assert ok5 == :ok
    edges = Enum.map(:digraph.edges(g), fn e -> Blxx.Dag.edge_vertices(g, e) end)
    assert Enum.all?(Enum.map([{:a, :b}, {:a, :c}, {:c, :d}, {:c, :e}, {:d, :e}], 
      fn e -> Enum.member?(edges, e) end))
    Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)
  end


  test "badvertex" do
    {:ok, {d, g}, f} = fileman()

    bad_d = "this is not a dets table"
    {e, _y} = Blxx.Dag.add_vertedge({bad_d, g}, :a) # bad dets table
    assert e == :error
    assert !Enum.member?(:digraph.vertices(g), :a)
    assert :digraph.vertices(g) == [:root]

    Blxx.Dag.add_vertedge({d, g}, :b, :z) # bad parent
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    assert !Enum.member?(:digraph.vertices(g), :b)
    assert :digraph.edges(g) == [] 
    assert (Enum.at(Blxx.Dag.dets_nodes(d), 0) |> elem(0)) == :root

    Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)
  end

  test "big_graph" do
    {:ok, {d, g}, f} = fileman()
    Blxx.Dag.close_store({d, g})
    assert :ok = File.rm!(f)

  end

  test "map_merges" do
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.bigdag()
    sg = Blxx.Dag.subqual(g, :root)
    {_, jmeta} = :digraph.vertex(sg, :j)
    assert Map.has_key?(jmeta, :la) 
    assert Map.has_key?(jmeta, :oui)
    assert Map.has_key?(jmeta[:la], "deux")
    assert Map.has_key?(jmeta[:la], "un")
    assert jmeta[:la]["un"] == 1
    assert jmeta[:la]["deux"] == 2
    {_, dmeta} = :digraph.vertex(sg, :d)
    assert Map.has_key?(dmeta, :a)
    assert dmeta[:a] == "b"
    Blxx.Dag.close_store({d, g})
  end


  test "bad_parent" do
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.fx()
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    assert Blxx.Dag.add_vertedge({d, g}, :a, :bad_parent) == {:error, "parent does not exist"}
    Blxx.Dag.close_store({d, g})
  end

   
  test "new_meta" do
    # see if we can change the meta of a vertex
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.fx()
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    {_, brlmeta} = :digraph.vertex(g, :USDBRL)

    sg = Blxx.Dag.subqual(g, :root) # fully qualified subgraph with copied meta from parent nodes
    {_, brlmeta2} = :digraph.vertex(sg, :USDBRL)
    assert brlmeta2[:desc] == "latin america"
  
    Blxx.Dag.change_vmeta({d, g}, :USDBRL, %{desc: "this_is_new_meta for USDBRL"})
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    {_, brlmeta3} = :digraph.vertex(g, :USDBRL)
    assert brlmeta3[:desc] == "this_is_new_meta for USDBRL"
    assert Map.keys(brlmeta3) == [:desc]
    Blxx.Dag.close_store({d, g})
  end

  
  test "edges_have_fields_and_tickers" do
    # TODO see if this works with {:ok, {d, g}, f} instead of just g
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.fx_with_sources()
    edges = :digraph.out_edges(g, :blp)
    assert Enum.all?(Enum.map(edges, fn e -> :digraph.edge(g, e) 
      |> elem(3) 
      |> Map.has_key?(:fields) end))
    assert Enum.all?(Enum.map(edges, fn e -> :digraph.edge(g, e) 
      |> elem(3) 
      |> Map.has_key?(:ticker) end))
    Blxx.Dag.close_store({d, g})
  end


  test "change_edge" do
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.fx_with_sources()
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    Blxx.Dag.change_emeta({d, g}, :blp, :USDBRL, %{new_meta: "this is new meta"}) 
    #Blxx.Dag.close_store({d, g})
    #{:ok, {d, g}} = Blxx.Dag.open_store(f)
    brlmeta = :digraph.out_edges(g, :blp) 
      |> Enum.map(fn e -> :digraph.edge(g, e) end) 
      |> Enum.filter(fn e -> e |> elem(2) == :USDBRL end)
      |> List.first
      |> elem(3)
    assert brlmeta == %{new_meta: "this is new meta"}
    Blxx.Dag.close_store({d, g})
  end


  test "no_add_duplicate_edge" do
    {:ok, {d, g}, f} = Blxx.Dag.DagExperiments.fx_with_sources()
    Blxx.Dag.close_store({d, g})
    {:ok, {d, g}} = Blxx.Dag.open_store(f)
    result = Blxx.Dag.add_edge({d, g}, :blp, :USDBRL,  %{ticker: "USDBRL Curncy", fields: ["LAST_PRICE"]})
    assert result == {:error, "edge already exists from parent"}
  end

    
end
