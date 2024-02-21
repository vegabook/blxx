defmodule Blxx.SubHandler do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    IO.puts "Starting SubHandler"
    {:ok, %{}}
  end

  def handle_cast({:received, message}, state) do
    # TODO put in data store
    data = Msgpax.unpack!(message)
    IO.puts "SubHandler :received data #{inspect(data)}"
    case data do
      ["info", _] -> IO.inspect(data)
      ["status", _] -> IO.inspect(data)
      _ -> nil
    end

    {:noreply, state}
  end

end


