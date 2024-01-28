defmodule Blxx.Database do
  use GenServer

  @regulator :timer.seconds(10)
  @truncto 150_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: opts[:name])
  end

  def init(db_state) do
    Process.send_after(self(), :regulate, @regulator)
    {:ok, db_state}
  end

  def handle_call({:insert, key, value}, _from, db_state) do
    {:reply, :ok, Map.put(db_state, key, [value | Map.get(db_state, key, [])])}
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
end
