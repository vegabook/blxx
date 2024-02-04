defmodule Blxx.Database do
  use GenServer

  @regulator :timer.seconds(10)
  @truncto 150_000
  # TODO remove all insert into the state variable and use ets instead

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(db_state) do
    Process.send_after(self(), :regulate, @regulator) # start the state regulator
    :ets.new(:blp, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
    {:ok, db_state}
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def insert(key, value) do
    # TODO make key much simpler than the whole cid so that ordered set works
    GenServer.cast(__MODULE__, {:insert, key, value})
  end


  def handle_cast({:insert, key, value}, db_state) do
    :ets.insert(:blp, {key, value})
    {:noreply, Map.put(db_state, key, [value | Map.get(db_state, key, [])])}
  end


  def handle_call(:get, _from, db_state) do
    {:reply, db_state, db_state}
  end

  
  def handle_call({:get, key, num}, _from, db_state) do
    vals =
      db_state
      |> Map.get(key, [])
      |> Enum.take(num)

    {:reply, vals, db_state}
  end

  @doc """
  periodically truncate the each list in the db_state to @truncto elements
  """
  def handle_info(:regulate, db_state) do
    # TODO log
    # ? spawn and handle_cast?
    trunc_state = for {key, val} <- db_state, into: %{}, do: {key, Enum.take(val, @truncto)}
    Process.send_after(self(), :regulate, @regulator)
    {:noreply, trunc_state}
  end

  def handle_call(:stop, _from, db_state) do
    IO.puts("Stopping Blxx.Database")
    {:stop, :normal, db_state}
  end
end
