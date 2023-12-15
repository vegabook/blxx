defmodule Blxx.Dag do
  @moduledoc """
  Stores ticker leaves and calculation nodes in a DETS table.
  TODO: convert to digraph
  TODO: move out of blxx_web and into blxx with others too that belong there
  """

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
      :dets.insert_new(:vstore, {:root, :vertex, Blxx.Util.utc_stamp(), %{desc: "root vertex"}})
      :dets.close(:vstore)
      open_vstore()
    else
      {:ok, :vstore}
    end
  end


  def close_vstore() do
    :dets.close(:vstore)
  end


  def store_vertex(
        v,
        parent \\ :root,
        meta \\ %{},
        ts \\ Blxx.Util.utc_stamp()
      ) do
    with {:vbin, true} <- {:vbin, is_atom(v)},
         {:pbin, true} <- {:pbin, is_atom(parent)},
         {:tsnum, true} <- {:tsnum, is_number(ts)},
         {:mmap, true} <- {:mmap, is_map(meta)},
         {:pexist, true} <- {:pexist, :dets.lookup(:vstore, parent) != []}
    do
      case :dets.insert_new(:vstore, {v, :vertex, ts, meta}) do
        true -> 
          case store_edge(parent, v) do
            {:ok, _} -> {:ok, v}
            {:error, _} -> {:error, "edge already exists"}
          end 
        false -> {:error, "vertex #{v} already exists"}
      end

    else
      {:vbin, false} -> {:error, "vname must be a string"}
      {:tsnum, false} -> {:error, "timestamp must be a number"}
      {:pbin, false} -> {:error, "parent must be an atom"}
      {:mmap, false} -> {:error, "meta must be a map"}
      {:pexist, false} -> {:error, "parent #{parent} does not exist"} 
    end
  end


  def store_edge(vp, vc, ts \\ Blxx.Util.utc_stamp()) do
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


end

