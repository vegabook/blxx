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
    assert :ok == Blxx.Dag.close_store(d)
    assert :ok = File.rm!(f)
  end

  
  test "add_vertex" do
    {:ok, {d, g}, f} = fileman()
    {isokay, x} = Blxx.Dag.add_vertex({d, g}, :a)
    assert isokay == :ok
    {isokay, x} = Blxx.Dag.add_vertex({d, g}, :b)
    assert isokay == :ok
    {isokay, x} = Blxx.Dag.add_vertex({d, g}, :c)
    assert isokay == :ok
    {isokay, x} = Blxx.Dag.add_edge({d, g}, :b, :c)
    assert isokay == :ok

    assert Enum.all?(
             Enum.map([:a, :b, :c, :root], fn v -> Enum.member?(:digraph.vertices(g), v) end)
           )

    assert :ok == Blxx.Dag.close_store(d)
    assert :ok = File.rm!(f)
  end


  test "make_fx" do
    {:ok, {d, g}, f} = fileman()

    {isokay, {d, g}} =
      Blxx.Dag.add_vertex({d, g}, :fx, :root, %{:asset_class => "foreign exchange"})

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

    {isokay, {_, _}} = Blxx.Dag.add_vertices({d, g}, currs, :fx, fn v -> %{ticker: to_string(v) <> " Curncy", source: :blp} end)
    assert isokay == :ok
    # print out all the vertices
    IO.inspect :digraph.vertices(g)
    # check if edges are all there
    edgevs = Enum.map(:digraph.edges(g), fn e -> Blxx.Dag.edge_vertices(g, e) end)
    assert Enum.all?(Enum.map(currs, fn v -> Enum.member?(edgevs, {:fx, v}) end))
    # check if vertices are all there
    assert Enum.all?(Enum.map(currs, fn v -> Enum.member?(:digraph.vertices(g), v) end))
    # cleanup
    Blxx.Dag.close_store(d)
    assert :ok = File.rm!(f)
  end


  test "addedge" do
    assert :ok  == :ok
  end


end
