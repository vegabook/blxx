defmodule Blxx.Dag do
  @moduledoc """
  Stores ticker leaves and calculation nodes in a DETS table.
  TODO: convert to digraph
  """
  use GenServer


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, table} = :dets.open_file(:dag, 
      [{:file, dagfilename()}, 
        {:type, :set}, 
        {:keypos, 1}, 
        {:repair, true}])
  end

  def dagfilename() do
    File.cwd! <> "/priv/dag.dets"
    |> String.to_charlist()
  end

  def add_leaf(vertex, value) do
    :dets.insert(:dag, {vertex, value})
  end

  def delete_leaf(vertex) do
    if Enum.empty? get_leaf(vertex) do
      {:error, "vertex not found"}
    else
      :dets.delete(:dag, vertex)
    end
  end

  def get_leaf(vertex) do
    :dets.lookup(:dag, vertex)
  end

  def all_leaves() do
    :dets.match(:dag, :"$1")
  end

  def delete_all() do
    :dets.match_delete(:dag, :"$1")
  end

end














