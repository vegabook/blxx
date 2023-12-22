defmodule Blxx.Dag do
  @moduledoc """
  Stores ticker leaves and calculation nodes in a DETS table.
  """

  # -------------- dets vstore ---------------

  def open_store(detspath) when is_binary(detspath) do
    charpath = detspath |> to_charlist

    with {:isdir, false} <- {:isdir, detspath |> String.slice(-1, 1) == "/"},
         {:direxists, true} <- {:direxists, detspath |> Path.dirname() |> File.exists?()},
         {:open, {:ok, _}} <-
           {:open,
            :dets.open_file(detspath, [
              {:file, charpath},
              {:type, :bag},
              {:keypos, 1},
              {:repair, true}
            ])} do
      if :dets.lookup(detspath, :root) == [] do
        clean_nodes(detspath)
      else
        {:ok, {detspath, expand_graph(:digraph.new(), dets_nodes(detspath))}}
      end
    else
      {:isdir, true} ->
        {:error, "detspath must include a filename"}

      {:direxists, false} ->
        {:error, "detspath directory doesn't exist"}

      {:open, {:error, reason}} ->
        {:error, reason}
    end
  end

  def open_store(detspath) when is_list(detspath) do
    # charlist 
    detspath |> to_string |> open_store
  end

  def close_store(dg) when is_tuple(dg) do
    {detspath, _graph} = dg
    :dets.close(detspath)
  end

  def close_store(detspath) do
    :dets.close(detspath)
  end

  def add_vertex({detspath, graph}, v, 
    parent \\ :root, 
    meta \\ %{}, 
    ts \\ Blxx.Util.utc_stamp()) do
    # store a vertex in the vstore and add it to the graph 
    # test if adding it works before committing to dets
    testgraph = graph

    with {:vatom, true} <- {:vatom, is_atom(v)},
         {:patom, true} <- {:patom, is_atom(parent)},
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:mmap, true} <- {:mmap, is_map(meta)},
         # do inserts on the test graph to make sure they work
         # no duplicate edge, also handles parent doesn't exist
         {:novdupe, true} <-
           {:novdupe, !Enum.member?(:digraph.out_neighbours(testgraph, parent), v)},
         # don't have to check dupe vertices becausing adding twice changes nothing even edges
         {:addvertex, v} <- {:addvertex, :digraph.add_vertex(testgraph, v, meta)},
         # add edge from parent to v
         {:addedge, [:"$e" | rest]} <- {:addedge, :digraph.add_edge(testgraph, parent, v)},
         # no failures then delete the testgraph from (non gc'd) ETS to save space
         {:deltestg, true} <- {:deltestg, :digraph.delete(testgraph)},
         # insert the instructions for this modification into the vstore
         {:insert, :ok} <-
           {:insert, :dets.insert(detspath, {v, parent, ts, :vertedge, meta})} do
      # since testgraph passed, we now rebuild the graph from the last insert
      {:ok, {detspath, expand_graph(graph, [{v, parent, ts, :vertedge, meta}])}}
    else
      {:vatom, false} ->
        {:error, "vertex must be an atom"}

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
        :dets.delete(detspath, {v, :vertedge, ts, parent, meta})
        {:error, reason}

      {:deltestg, _} ->
        {:error, "testgraph delete failed"}

      {:insert, false} ->
        {:error, "vertex insert failed"}
    end
  end


  def add_vertices({detspath, graph}, 
    vlist, 
    parent, 
    metafun \\ fn _ -> %{} end,
    ts) do
    # add a list of vertices to the vstore and graph
    # metafun is a function that takes a vertex and returns a map
    # eg. fn v -> %{desc: "vertex #{v}"} end
    with {:vlist, true} <- {:vlist, is_list(vlist)} do
      List.foldl(vlist, {:ok, {detspath, graph}}, fn v, acc ->
        case acc do
          {:ok, {detspath, graph}} ->
            add_vertex({detspath, graph}, v, parent, metafun.(v), ts)

          {:error, reason} ->
            {:error, reason}
        end
      end)
    else
      {:vlist, false} ->
        {:error, "vlist must be a list"}
    end
  end


  def add_edge({detspath, graph}, parent, child, ts \\ Blxx.Util.utc_stamp()) do
    # store an edge in the vstore and add it to the graph
    # not usually needed as store_vertex always takes a parent but
    # needed when adding edges to existing vertices eg. for overlapping groups
    testgraph = graph

    with {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:novdupe, true} <-
           {:novdupe, !Enum.member?(:digraph.out_neighbours(testgraph, parent), child)},
         {:addedge, [:"$e" | rest]} <-
           {:addedge, :digraph.add_edge(testgraph, parent, child)},
         {:insert, ok} <-
           {:insert, :dets.insert(detspath, {child, parent, ts, :edge, %{}})} do
      {:ok, {detspath, expand_graph(graph, [{child, parent, ts, :edge, %{}}])}}
    else
      false -> {:error, "v1 and v2 must be atoms"}
      {:tsnum, false} -> {:error, "timestamp must be a number"}
      {:addedge, {:error, reason}} -> {:error, reason}
      {:insert, false} -> {:error, "edge insert failed"}
      {:novdupe, false} -> {:error, "edge already exists from parent"}
    end
  end

  def dets_nodes(detspath) do
    # get all the vertices, vertedges, and edges from the vstore
    :dets.foldl(fn elem, acc -> [elem | acc] end, [], detspath)
    |> Enum.sort_by(fn x -> elem(x, 2) end)
  end

  def clean_nodes(detspath) do
    # remove all vertices, vertedges, and edges from the vstore
    :dets.delete_all_objects(detspath)

    :dets.insert_new(
      detspath,
      {:root, None, Blxx.Util.utc_stamp(), :vertex, %{desc: "root vertex"}}
    )

    {:ok, {detspath, expand_graph(:digraph.new(), dets_nodes(detspath))}}
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
          nil
          # TODO
      end
    end)

    graph
  end
end
