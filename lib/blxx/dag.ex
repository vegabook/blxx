defmodule Blxx.Dag do
  @moduledoc """
  Stores ticker leaves and calculation nodes in a DETS table.
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
      {:type, :bag},
      # key is first element of tuple
      {:keypos, 1},
      {:repair, true}
    ])

    if :dets.lookup(:vstore, :root) == [] do
      clean_vstore()

      :dets.insert_new(
        :vstore,
        {:root, None, Blxx.Util.utc_stamp(), :vertex, %{desc: "root vertex"}}
      )

      :dets.close(:vstore)
      open_vstore()
    else
      expand_graph(:digraph.new(), get_vstore())
    end
  end

  def close_vstore() do
    :dets.close(:vstore)
  end


  def store_vertex(graph, v, parent \\ :root, meta \\ %{}, ts \\ Blxx.Util.utc_stamp()) do
    # store a vertex in the vstore and add it to the graph 
    testgraph = graph

    with {:vatom, true} <- {:vatom, is_atom(v)},
         {:patom, true} <- {:patom, is_atom(parent)},
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:mmap, true} <- {:mmap, is_map(meta)},
         # no duplicate edge, also handles parent doesn't exist
         {:novdupe, true} <- {:novdupe, !Enum.member?(:digraph.out_neighbours(testgraph, parent), v)},
         # don't have to check dupe vertices becausing adding twice changes nothing even edges
         {:addvertex, v} <- {:addvertex, :digraph.add_vertex(testgraph, v, meta)},
         # add edge from parent to v
         {:addedge, [:"$e" | rest]} <- {:addedge, :digraph.add_edge(testgraph, parent, v)},
         # insert the instructions for this modification into the vstore
         {:insert, :ok} <-
           {:insert, :dets.insert(:vstore, {v, parent, ts, :vertedge, meta})} do
      # since testgraph passed, we now rebuild the graph from the last insert
      expand_graph(graph, [{v, parent, ts, :vertedge, meta}])
    else
      {:vatom, false} ->
        {:error, "vname must be an atom"}

      {:patom, false} ->
        {:error, "parent must be an atom"}

      {:tsnum, false} ->
        {:error, "timestamp must be a number"}

      {:mmap, false} ->
        {:error, "meta must be a map"}

      {:novdupe, false} ->
        {:error, "vertex already exists from parent"}

      {:addvertex, {:error, reason}} ->
        {:error, reason}

      {:addedge, {:error, reason}} ->
        :dets.delete(:vstore, {v, :vertedge, ts, parent, meta})
        {:error, reason}

      {:insert, false} ->
        {:error, "vertex insert failed"}
    end
  end

  def store_edge(graph, parent, child, ts \\ Blxx.Util.utc_stamp()) do
    # store an edge in the vstore and add it to the graph
    # not usually needed as store_vertex always takes a parent but
    # needed when adding edges to existing vertices eg. for overlapping groups
    testgraph = graph

    with {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:addedge, [:"$e" | rest]} <-
           {:addedge, :digraph.add_edge(testgraph, parent, child)},
         {:insert, ok} <-
           {:insert, :dets.insert(:vstore, {child, parent, ts, :edge, %{}})} do
      expand_graph(graph, [{child, parent, ts, :edge, %{}}])
    else
      false -> {:error, "v1 and v2 must be atoms"}
      {:tsnum, false} -> {:error, "timestamp must be a number"}
      {:addedge, {:error, reason}} -> {:error, reason}
      {:insert, false} -> {:error, "edge insert failed"}
    end
  end

  def delete_subtree(graph, v) do
    # delete a vertex and all its children that don't have other parent vertices
    :ok
  end

  def delete_edge(graph, vp, vc) do
    # must find the edge then delete it
    :ok
  end

  def get_vstore() do
    # get all the vertices, vertedges, and edges from the vstore
    :dets.foldl(fn elem, acc -> [elem | acc] end, [], :vstore)
    |> Enum.sort_by(fn x -> elem(x, 2) end)
  end

  def clean_vstore() do
    # remove all vertices, vertedges, and edges from the vstore
    :dets.delete_all_objects(:vstore)
  end

  # -------------- digraph vgraph ------------------

  def edge_vertices(graph, edge) do
    # returns the vertices of an edge
    {_, v1, v2, _} = :digraph.edge(graph, edge)
    {v1, v2}
  end

  def expand_graph(graph, tsnodes) do
    # given sorted tsnodes create a digraph
    Enum.map(tsnodes, fn {v, parent, ts, type, meta} ->
      IO.puts "v: #{v}, parent: #{parent}, ts: #{ts}, type: #{type}, meta: #{inspect(meta)}"
      case type do
        :vertex ->
          :digraph.add_vertex(graph, v, meta)

        :vertedge ->
          :digraph.add_vertex(graph, v, meta)
          :digraph.add_edge(graph, parent, v)

        :edge ->
          :digraph.add_edge(graph, parent, v)

        :deledge ->
          :digraph.del_path(graph, parent, v)

        :delsubtree ->
          {:TODO, graph}
      end
    end)

    {:ok, graph}
  end
end
