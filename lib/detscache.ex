defmodule Blxx.DetsCache do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Application.get_env(:blxx, :dets_dir)
    |> Path.join("subs.dets")
    |> String.to_charlist()
    |> IO.inspect()
    |> :dets.open_file([{:type, :set}])
  end


  def handle_call({:put, key, value}, _from, table) do
    # usage: GenServer.call(Blxx.DetsCache, {:put, "zing", 3})
    :dets.insert(table, {key, value})
    {:reply, :ok, table}
  end


  def handle_call({:get, key}, _from, table) do
    # usage: GenServer.call(Blxx.DetsCache, {:get, "zing"})
    value = :dets.lookup(table, key)
    {:reply, value, table}
  end


  def handle_call({:delete, key}, _from, table) do
    value = :dets.delete(table, key)
    {:reply, value, table}
  end


  def handle_call(:first, _from, table) do
    # usage: GenServer.call(Blxx.DetsCache, :all)
    value = :dets.first(table)
    {:reply, value, table}
  end


  def handle_call(:all, _from, table) do
    value = :dets.foldl(fn elem, acc -> [elem | acc] end, [], table)
    {:reply, value, table}
  end


end


    

    
    
