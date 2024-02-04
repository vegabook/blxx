defmodule Blxx.SubHandler do
  use GenServer
  """

    case payload do
      ["subdata", %{"timestamp" => timestamp, "topic" => topic, "prices" => prices}] ->
        for %{"field" => field, "value" => value} <- prices do
          %Tick{source: "bbg", topic: topic, fld: field, value: value, timestamp: timestamp}
          |> IO.inspect()
        end


      ["refdata", x] -> 
        # TODO over here send this to the Blxx.RefHandler because it will already
        #   have been told by Blxx.Com.whateverRequest to expect it
        IO.puts "Received refdata"
        IO.inspect(x)

      ["info", %{"request_type" => request_type, "structure" => structure}] ->
        IO.puts "Received info structure"
        IO.puts(request_type)
        IO.puts(structure)

      ["info", infomsg] ->
        IO.puts "Received info"
        IO.inspect payload

      anything ->
        IO.puts "Received anything"
        IO.inspect(anything)
        :ok
    end

"""

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    IO.puts "Starting SubHandler"
    {:ok, %{}}
  end

  def handle_cast({:received, message}, state) do
    # TODO handle
    data = Msgpax.unpack!(message)
    case data do
      ["info", _] -> IO.inspect(data)
      ["status", _] -> IO.inspect(data)
      ["ping", send_time] -> 
        stamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond) |> (&(&1 / 1000000)).()
        Blxx.Com.com({:blp, [:pong, send_time, stamp]})
      _ -> nil
    end

    {:noreply, state}
  end

end


