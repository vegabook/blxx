defmodule BlxxWeb.BbgSocket do
  @behaviour Phoenix.Socket.Transport
  @resp_ref 1
  @moduledoc """
  This module implements the Phoenix.Socket.Transport behaviour for a websocket
  to communicate with the bloomberg terminal. 
  Inspired by: https://furlough.merecomplexities.com/elixir/phoenix/tutorial/2021/02/19/binary-websockets-with-elixir-phoenix.html
  """

  alias Blxx.Tick
  alias Blxx.Bar

  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: %{"id" => id, "key" => key}}) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    IO.puts("connection requested")
    if key != System.get_env("BLXXKEY") do
      IO.puts("Key is not correct")
      {:error, :unauthorized}
    else
      IO.puts("Connected #{id}")
      {:ok, %{id: id}}
    end
  end

  def init(state) do
    # register this pid with the registry
    Registry.register(Blxx.Registry, :bbgsocket_pid, self())
    {:ok, state}
  end

  def in_handler(data) do
    # unpack 8 pbyte msgpack size header
    <<header::binary-size(8), message::binary>> = data
    <<msgtype::little-integer-size(64)>> = header

    # insertdb function TODO fix?
    insert_db = fn bar -> GenServer.call(Database, {:insert, bar.topic, bar}) end

    payload =
      if msgtype == @resp_ref do
        Msgpax.unpack!(message) # TODO put into a separate process because big
      else
        Msgpax.unpack!(message)
      end

    case payload do
      ["subdata", %{"timestamp" => timestamp, "topic" => topic, "prices" => prices}] ->
        for %{"field" => field, "value" => value} <- prices do
          %Tick{source: "bbg", topic: topic, fld: field, value: value, timestamp: timestamp}
          |> IO.inspect()
        end

      ["ping", _timestamp] ->
        :ok

      [
        "bardata",
        %{
          "msgtype" => msgtype,
          "topic" => topic,
          "interval" => interval,
          "numticks" => numticks,
          "open" => open,
          "high" => high,
          "low" => low,
          "close" => close,
          "volume" => volume,
          "timestamp" => timestamp
        }
      ] ->
        %Bar{
          source: "bbg",
          msgtype: msgtype,
          topic: topic,
          interval: interval,
          numticks: numticks,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          timestamp: timestamp
        }
        |> insert_db.()

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
  end

  def handle_in({data, _opts}, state) do
    # DATA comes back handler
    # TODO might not have to spawn unless it's reference data. 
    # check spawn design pattern in general with responsibility boundaries
    # TODO handle correlation IDs well
    # TODO test minute bars
    # TODO database move to disk_log?
    spawn(fn -> in_handler(data) end)
    {:ok, state}
  end

  def handle_info({:com, command}, state) do
    # commands handler
    IO.puts("Received command: #{inspect(command)}")
    {:push, {:binary, Msgpax.pack!(command)}, state}
  end

  def handle_info(m, state) do
    IO.puts("Received default handler message: #{inspect(m)}")
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
