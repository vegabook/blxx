defmodule Blxx.Database do
  use GenServer

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(db_state) do
    {:ok, %{}}
  end 


  @doc """
  Prepends a value into the list stored under key.
  If a key does not exist, it is created using default in Map.get
  """
  def handle_call({:insert, key, value}, _from, db_state) do
    {:reply, :ok, Map.put(db_state, key, [value | Map.get(db_state, key, [])])}
  end

  @doc """ 
  Returns the last n elements of the list stored under key
  """
  def hande_call({:get, key, num}, fromwho, db_state) do
    IO.inspect fromwho
    {:reply, Map.get(db_state, key, []), db_state}
  end

end
