defmodule Blxx.Dag do
  @moduledoc """
  A graph-creation append-only log. Keeps a list of instructions on how to recreate a graph
  in a dets table, and allows for the graph and dets to evolve using atomic operations that will affect
  both or neither. All timestamped so that historic states can be recreated.
  """

  # TODO ability to remove subtrees and their associated edges
  # TODO how to handle ordering since for some asset classes we will add lots of vertices and edges later
  #      possibly move to mnesia instead of dets. Then can index on timestamp but Q: can "next" in index be used?
  #      * Alternatively use DETS table but key on timestamp and not on vertex name
  #      This will allow for getting all the keys, then sorting them and rewriting the graph

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

  def close_store(dg) when is_tuple(dg) and tuple_size(dg) == 2 do
    {detspath, _graph} = dg
    :dets.close(detspath)
  end

  def close_store(detspath) when is_binary(detspath) do #string
    :dets.close(detspath)
  end


  defp atomic_vedge({detspath, graph}, v, parent, meta, ts) do
    # atomic add of a vertex and its edge to parent and save to dets
    # if any stage fails preceding successes are rolled back
    # yes nested case anti pattern yada but this is fine with only 3 levels
    # https://elixirforum.com/t/pattern-matching-using-first-rest-in-with-clause-seems-to-fail/60541 
    case :digraph.add_vertex(graph, v, meta) do
      # TODO handle metadata change or augmentation. Maybe force new vertex, but then don't re-add edge. 
      #     or maybe something else. 
      v -> 
        case :digraph.add_edge(graph, parent, v) do
          [:"$e" | rest] ->

            dets_result = 
            try do
              :dets.insert(detspath, {v, parent, ts, :vertedge, meta})
            rescue
              e in ArgumentError -> {:error, e}
            end

            case dets_result do 
              :ok -> {:ok, {detspath, graph}} # success function returns
              # dets fail so rollback edge and vertex inserts
              {:error, e} ->
                :digraph.del_edge(graph, [:"$e" | rest])
                :digraph.del_vertex(graph, v)
                {:error, e}
            end
          # edge insert fail so rollback vertex insert
          {:error, reason} ->
            :digraph.del_vertex(graph, v)
            {:error, reason}
        end 
      # vertex insert fail so return error
      some_error ->
        {:error, some_error}
    end
  end


  def add_vertex({detspath, graph}, v, 
    parent \\ :root, 
    meta \\ %{}, 
    ts \\ Blxx.Util.utc_stamp()) do
    # store a vertex in the vstore and add it to the graph 
    # test if adding it works before committing to dets
    with {:vatom, true} <- {:vatom, is_atom(v)},
         {:patom, true} <- {:patom, is_atom(parent)},
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:mmap, true} <- {:mmap, is_map(meta)} do
         # do inserts on the test graph to make sure they work
         # no duplicate edge, also handles parent doesn't exist
      atomic_vedge({detspath, graph}, v, parent, meta, ts)
    else
      {:vatom, false} ->
        {:error, "vertex must be an atom"}

      {:patom, false} ->
        {:error, "parent must be an atom"}

      {:tsnum, false} ->
        {:error, "timestamp must be a number"}

      {:mmap, false} ->
        {:error, "meta must be a map"}

    end
  end


  def add_vertices({detspath, graph}, 
    vlist, 
    parent, 
    metafun \\ fn _ -> %{} end,
    ts \\ Blxx.Util.utc_stamp()) do
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
    # atomic like atomic_vedge but with no vertex insert
    with {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:novdupe, true} <-
           {:novdupe, !Enum.member?(:digraph.out_neighbours(graph, parent), child)} do
      case :digraph.add_edge(graph, parent, child) do
        [:"$e" | rest] ->

            dets_result = 
            try do
              :dets.insert(detspath, {child, parent, ts, :edge, %{}})
            rescue
              e in ArgumentError -> {:error, e}
            end

          case dets_result do 
            :ok -> {:ok, {detspath, graph}}
            false ->
              :digraph.del_edge(graph, [:"$e" | rest])
              {:error, "dets edge insert failed"}
          end
        {:error, reason} -> {:error, reason}
      end
    else
      {:tsnum, false} -> {:error, "timestamp must be a number"}
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
    # dangerous!
    :dets.delete_all_objects(detspath)

    :dets.insert_new(
      detspath,
      {:root, None, Blxx.Util.utc_stamp(), :vertex, %{}}
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
    # given sorted tsnodes, extend graph with them
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


  def leaves(graph, root \\ [:root]) # defined header for default value
  # gets all the leaves of a graph, optionally starting somewhere
  # other than :root node

  def leaves(graph, root) when is_list(root) do
    :digraph_utils.reachable_neighbours(root, graph)
    |> Enum.filter(fn v -> :digraph.out_degree(graph, v) == 0 end)
    |> Enum.map(fn v -> :digraph.vertex(graph, v) end)
  end

  def leaves(graph, root) when is_atom(root) do
    leaves(graph, [root])
  end

  
  def inters(graph, root \\ [:root])
  # gets all the internal nodes of a graph, optionally starting somewhere
  # other than :root node

  def inters(graph, root) when is_list(root) do
    :digraph_utils.reachable_neighbours(root, graph)
    |> Enum.filter(fn v -> :digraph.out_degree(graph, v) > 0 end)
    |> Enum.map(fn v -> :digraph.vertex(graph, v) end)
  end

  def inters(graph, root) when is_atom(root) do
    inters(graph, [root])
  end

  @doc """
  recursive subtree of a graph with starting node root
  all meta kv pairs of parent nodes will be passed to
  child nodes unless overridden by child nodes
  """
  def subqual(graph, root, newgraph \\ :digraph.new(), pmeta \\ %{}) when is_atom(root) do
    # TODO make this into separate allchildren function that then has equivalent of allmeta
    {n, meta} = :digraph.vertex(graph, root)
    # recursive merge the maps. NB clashing keys closer node wins
    newmeta = Blxx.Util.deep_merge(pmeta, meta) 
    
    :digraph.add_vertex(newgraph, n, newmeta)
    for v <- :digraph.out_neighbours(graph, root) do
      subqual(graph, v, newgraph, newmeta)
    end
    for v <- :digraph.out_neighbours(graph, root) do
      :digraph.add_edge(newgraph, root, v)
    end
    newgraph
  end


  @doc """
  get all the meta of a node and its parents 
  """
  def allParents(graph, node, parents \\ [])
  # this is a header because of the default argument

  def allParents(graph, node, parents) do
    Enum.reduce(:digraph.in_neighbours(graph, node), parents, fn v, acc ->
      [v | allParents(graph, v, acc)]
    end)
  end

  def allParents(graph, :root, parents) do
    parents
  end


  @doc """ 
  get all the meta of a node and its parents 
  """
  def allMeta(graph, node) do
    with {_, _} <- :digraph.vertex(graph, node) do
      [node] ++ allParents(graph, node)
      |> Enum.map(fn v -> :digraph.vertex(graph, v) end)
    else
      false -> []
    end
  end

  
  @doc """
  flatten the output of allMeta maps into a single map
  """
  def flattenMeta(metalist) do
      Enum.reduce(metalist, %{}, fn {_, x}, acc ->
        Map.merge(acc, x)
      end)
  end


end
