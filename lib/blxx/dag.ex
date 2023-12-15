defmodule Blxx.Dag do
  @moduledoc """
  Stores ticker leaves and calculation nodes in a DETS table.
  TODO: convert to digraph
  TODO: move out of blxx_web and into blxx with others too that belong there
  """

  # -------------- dets vstore ---------------

  def open_vstore() do
    filepath =
      "~/.config/blxx/"
      |> Path.expand()
      |> Path.join("vstore.dets")
      |> to_charlist()

    if not File.exists?(filepath) do
      File.mkdir_p(Path.dirname(filepath))
    end

    :dets.open_file(:vstore, [
      {:file, filepath}, 
      {:type, :set}, 
      {:keypos, 1}, # key is first element of tuple
      {:repair, true}])

    if :dets.lookup(:vstore, :root) == [] do
      :dets.insert_new(:vstore, {:root, :vertex, Blxx.Util.utc_stamp(), 
        None, %{desc: "root vertex"}})
      :dets.close(:vstore)
      open_vstore()
    else
      graph = expand_graph(:digraph.new(), get_store())
      {:ok, :vstore, graph}
    end
  end

  def close_vstore() do
    :dets.close(:vstore)
  end


  def store_vertex(
        graph,
        v,
        parent \\ :root,
        meta \\ %{},
        ts \\ Blxx.Util.utc_stamp()
      ) do
    
    with {:vbin, true} <- {:vbin, is_atom(v)},
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:mmap, true} <- {:mmap, is_map(meta)},
         {:pexist, true} <- {:pexist, :dets.lookup(:vstore, parent) != []},
         {:vexist, false} <- {:vexist, Enum.member?(:digraph.vertices(graph), v)},
         {:eexist, false} <- {:eexist, Enum.member?(Enum.map(:digraph.edges(graph), 
              fn x -> edge_vertices(graph, x) end), {parent, v})}
    do
      case :dets.insert_new(:vstore, {v, :vertedge, ts, parent, meta}) do
        # TODO mkust add the vertex and edges to the graph here and return them too
        true -> {:ok, v}
        false -> {:error, "vertex #{v} already exists"}
      end

    else
      {:vbin, false} -> {:error, "vname must be a string"}
      {:tsnum, false} -> {:error, "timestamp must be a number"}
      {:mmap, false} -> {:error, "meta must be a map"}
      {:pexist, false} -> {:error, "parent #{parent} does not exist"} 
      {:vexist, true} -> {:error, "vertex #{v} already exists"}
      {:eexist, true} -> {:error, "edge #{parent} to #{v} already exists"}

    end
  end


  def store_edge(graph, vp, vc, ts \\ Blxx.Util.utc_stamp()) do
    with true <- is_atom(vp),
         true <- is_atom(vc), 
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:pexist, true} <- {:pexist, :dets.lookup(:vstore, vp) != []},
         {:cexist, true} <- {:cexist, :dets.lookup(:vstore, vc) != []} do
      case :dets.insert_new(:vstore, {{vp, vc}, :edge, ts}) do
        true -> {:ok, {vp, vc}}
        false -> {:error, "edge #{vp} to #{vc} already exists"}
      end
    else
      false -> {:error, "v1 and v2 must be atoms"}
      {:pexist, false} -> {:error, "parent #{vp} does not exist"}
      {:cexist, false} -> {:error, "child #{vc} does not exist"}
      {:tsnum, false} -> {:error, "timestamp must be a number"}

    end
  end


  def get_store() do
    :dets.foldl(fn elem, acc -> [elem | acc] end, [], :vstore)
    |> Enum.sort_by(fn x -> elem(x, 2) end)
  end


  # -------------- digraph vgraph ------------------

  def edge_vertices(graph, edge) do
    {_, v1, v2, _} = :digraph.edge(graph, edge)
    {v1, v2}
  end


  def expand_graph(graph, tsnodes) do
    # given sorted tsnodes create the graph
    Enum.map(tsnodes, fn x -> 
      case elem(x, 1) do
        :vertex -> :digraph.add_vertex(graph, elem(x, 0), elem(x, 4))
        :vertedge -> 
          :digraph.add_vertex(graph, elem(x, 0), elem(x, 4))
          :digraph.add_edge(graph, elem(x, 3), elem(x, 0))
        :edge -> :digraph.add_edge(graph, elem(x, 0) |> elem(0), elem(x, 0) |> elem(1))
      end
    end)
    {:ok, graph}
  end 


end

