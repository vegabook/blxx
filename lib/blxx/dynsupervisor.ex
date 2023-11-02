defmodule Blxx.DynSupervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_barhandler(params) do
    spec = %{id: BarHandler, start: {BarHandler, :start_link, params}} 
    ret = DynamicSupervisor.start_child(__MODULE__, spec)
    # ret should be {:ok, correlid}
    IO.puts "in start_barhandler, about to show ret which should be {:ok, correid}"
    IO.inspect ret
  end

  def stop_barhandler(pid) do
    # TODO
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end


end
