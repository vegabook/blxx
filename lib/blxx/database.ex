defmodule Blxx.Database do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, %{}}
  end 

  def handle_call({:insert, key, value}, _from, state) do
    {:reply, :ok, Map.put(state, key, value)}
  end

end
