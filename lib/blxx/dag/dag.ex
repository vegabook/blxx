defmodule Blxx.Dag do
  @moduledoc """
  A graph-creation append-only log. Keeps a list of instructions on how to recreate a graph
  in a dets table, and allows for the graph and dets to evolve using atomic operations that will affect
  both or neither. All timestamped so that historic states can be recreated.
  """

  # -------------- dets operations ---------------

  @vertact [:addroot, :addvertex, :addedge, :addmeta, :addemeta, :deledge, 
    :delvertex, :chgmeta, :chgemeta, :delmeta, :delemeta]

  def list_vertacts(), do: @vertact

  def open_store(detspath) when is_binary(detspath) do
    charpath = detspath |> to_charlist

    with {:isdir, false} <- {:isdir, detspath |> String.slice(-1, 1) == "/"},
         {:direxists, true} <- {:direxists, detspath |> Path.dirname() |> File.exists?()},
         {:open, {:ok, _}} <-
           {:open,
            :dets.open_file(detspath, [
              {:file, charpath},
              {:type, :bag},
              {:keypos, 2},
              {:repair, true}
            ])} do
      if :dets.lookup(detspath, :root) == [] do
        clean_nodes(detspath)
      else
        {:ok, {detspath, expand_graph(Graph.new(), dets_nodes(detspath))}}
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


  def close_store({detspath, graph}) do
    :dets.close(detspath)
  end

  
  def dets_nodes(detspath) do
    # get all the vertices, vertedges, and edges from the vstore
    :dets.foldl(fn elem, acc -> [elem | acc] end, [], detspath)
  end

  def graph_hash_fun(vertex) do
    # hash the vertex to a unique identifier, because otherwise
    # run into major libgraph bug where phash does not provide enough hash width
    :crypto.hash(:sha256, :erlang.term_to_binary(vertex))
  end


  def clean_nodes(detspath) do
    # remove all vertices, vertedges, and edges from the vstore
    # and add a root node
    :dets.delete_all_objects(detspath)
    root = {:root, None, Blxx.Util.utc_stamp(), :addroot, %{}}
    {:ok, graph} = commit([root], detspath, Graph.new(vertex_identifier: &graph_hash_fun/1))
    {:ok, {detspath, graph}}
  end

  # -------------- graph operations ---------------

  defp node_sort_score(tsnode) do
  # used to sort so that vertices come first, then edges, then deledges
    score_add = list_vertacts() |> Enum.with_index |> Map.new |> Map.get(elem(tsnode, 3)) 
    # sort by timestamp, then by score, and invert because we will recurse
    elem(tsnode, 2) * 10 + score_add
  end


  defp single_tsnode_add(graph, tsnode) do
    case tsnode do
      # TODO with clauses here
      {v, p, ts, :addroot, meta} -> 
        newgraph = graph 
          |> Graph.add_vertex(v, meta)
        {:ok, newgraph}
      {v, p, ts, :addvertex, meta, emeta} -> 
        newgraph = graph 
          |> Graph.add_vertex(v, meta)
          |> Graph.add_edge(p, v, label: emeta)
        {:ok, newgraph}
      {v, p, ts, :addedge, emeta} -> 
        IO.puts ":addedge @{Blxx.Util.utc_stamp()}"
        newgraph = graph |> Graph.add_edge(p, v, label: emeta)
        {:ok, newgraph}
      {v, p, ts, :deledge} -> 
        IO.puts ":deledge @{Blxx.Util.utc_stamp()}"
        newgraph = graph |> Graph.del_edge(p, v)
        {:ok, newgraph}
      {v, p, ts, :delvertex} ->
        IO.puts ":delvertex @{Blxx.Util.utc_stamp()}"
        newgraph = graph |> Graph.del_vertex(v)
        {:ok, newgraph}
      {v, _, _, :chgmeta, newmeta} -> 
        IO.puts ":chgmeta @{Blxx.Util.utc_stamp()}"
        newgraph = graph 
          |> Graph.remove_vertex_labels(v) 
          |> Graph.label_vertex(v, newmeta)
        {:ok, newgraph}
      {v, p, _, :chgemeta, newmeta} ->
        IO.puts ":chgemeta @{Blxx.Util.utc_stamp()}"
        {:error, ":chgemeta not yet implemented"}
      {v, _, _, :delmeta, _} -> 
        IO.puts ":delmeta @{Blxx.Util.utc_stamp()}"
        {:error, ":delmeta not yet implemented"}
      {v, p, _, :delemeta, _} -> 
        IO.puts ":delemeta @{Blxx.Util.utc_stamp()}"
        {:error, ":delemeta not yet implemented"}
    end
  end

  defp expand_graph(graph, tsnodes) do

    # use an enum to expand the graph
    sorted_nodes = Enum.sort_by(tsnodes, fn tsnode -> node_sort_score(tsnode) end)
    x = List.foldl(sorted_nodes, {:ok, graph}, fn tsnode, status ->
      case status do
        {:ok, graph} -> 
          single_tsnode_add(graph, tsnode)
        {:error, reason} -> 
          {:error, reason}
      end
    end)
    IO.inspect x
  end

  @doc """ 
  Commit a list of tsnodes to the detspath, and expand the graph with them.
  """
  def commit(vlist, detspath, graph, expand_fun \\ &expand_graph/2) do
    # first validate it
    case expand_fun.(graph, vlist) do
      {:ok, newgraph} -> 
        # then commit it
        :dets.insert(detspath, vlist)
        {:ok, newgraph}
      {:error, reason} -> {:error, reason}
    end
  end


  @doc """
  Make a vertex tsnode with a parent, metadata, and edge metadata.
  """
  def make_vertex(v, 
    parent \\ :root, 
    meta \\ %{}, 
    emeta \\ %{},
    ts \\ Blxx.Util.utc_stamp()) do
    {v, parent, ts, :addvertex, meta, emeta}
  end

  @doc """
  Make an edge tsnode with a parent, child, and metadata.
  """
  def make_edge(parent, 
    child, 
    meta \\ {}, 
    ts \\ Blxx.Util.utc_stamp()) do
    {child, parent, ts, :addedge, meta}
  end

  @doc """
  Make an edge deletion tsnode.
  """
  def make_deledge(parent, 
    child, 
    ts \\ Blxx.Util.utc_stamp()) do
    {child, parent, ts, :deledge}
  end

  @doc """ 
  Make a vertex deletion tsnode.
  """
  def make_delvertex(v, 
    ts \\ Blxx.Util.utc_stamp()) do
    {v, None, ts, :delvertex}
  end

  @doc """
  Make a vertex metadata change tsnode.
  """
  def make_chgmeta(v, 
    newmeta, 
    ts \\ Blxx.Util.utc_stamp()) do
    {v, None, ts, :chgmeta, newmeta}
  end

  @doc """
  Make an edge metadata change tsnode.
  """
  def make_chgemeta(parent, 
    child, 
    newmeta, 
    ts \\ Blxx.Util.utc_stamp()) do
    {child, parent, ts, :chgemeta, newmeta}
  end 

  @doc """
  Make a vertex metadata deletion tsnode.
  """
  def make_delmeta(v, 
    ts \\ Blxx.Util.utc_stamp()) do
    {v, None, ts, :delmeta}
  end

  @doc """
  Make an edge metadata deletion tsnode.
  """
  def make_delemeta(parent, 
    child, 
    ts \\ Blxx.Util.utc_stamp()) do
    {child, parent, ts, :delemeta}
  end 
 


end
