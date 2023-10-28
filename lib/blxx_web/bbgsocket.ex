defmodule BlxxWeb.BbgSocket do
  @behaviour Phoenix.Socket.Transport
  @moduledoc """
  This module implements the Phoenix.Socket.Transport behaviour for a websocket
  to communicate with the bloomberg terminal. 
  Inspired by: https://furlough.merecomplexities.com/elixir/phoenix/tutorial/2021/02/19/binary-websockets-with-elixir-phoenix.html
  """

  alias Blxx.Tick
  alias Blxx.Bar
  alias Blxx.Repo


  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end


  def connect(%{params: %{"id" => id, "key" => key}}) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    if key != System.get_env("BLXXKEY") do
      IO.puts "Key is not correct"
      {:error, :unauthorized}
    else 
      IO.puts "Connected #{id}"
      {:ok, %{id: id}} 
    end
  end


  def init(state) do
    # register this pid with the registry
    Registry.register(Blxx.Registry, :bbgsocket_pid, self())
    {:ok, state}
  end


  def handle_in({data, _opts}, state) do
    d = Msgpax.unpack!(data)

    case d do

      %{"subdata" => %{"timestamp" => timestamp,
        "topic" => topic,
        "prices" => prices}} ->
          for %{"field" => field, "value" => value} <- prices do
            %Tick{source: "bbg", topic: topic, fld: field, value: value, timestamp: timestamp}
            |> IO.inspect
          end

      %{"ping" => _timestamp} -> :ok

      %{"bardata" => %{"msgtype" => msgtype,
        "topic" => topic,
        "interval" => interval,
        "numticks" => numticks,
        "open" => open,
        "high" => high,
        "low" => low,
        "close" => close,
        "volume" => volume,
        "timestamp" => timestamp}} -> %Bar{source: "bbg",
            msgtype: msgtype, 
            topic: topic, 
            interval: interval, 
            numticks: numticks, 
            open: open, 
            high: high, 
            low: low, 
            close: close, 
            volume: volume,
            timestamp: timestamp}
          |> IO.inspect

      %{"info" => %{"request_type" => request_type, "structure" => structure}} -> 
        IO.puts request_type
        IO.puts structure

      %{"key" => key} -> 
        IO.puts "Received key: #{IO.inspect key}"
        [enc_key] = :public_key.pem_decode(key)
        dkey = :public_key.pem_entry_decode(enc_key)
        challenge = :public_key.encrypt_public("hello", dkey, [rsa_padding: :rsa_pkcs1_oaep_padding])
        send(self(), {:challenge, challenge})

      junk -> IO.inspect junk

    end
    {:ok, state}
  end


  def handle_info({:challenge, challenge}, state) do
    # send the challenge back
    cpack = Msgpax.pack!(%{"challenge" => challenge})
    {:push, {:binary, cpack}, state}
  end


  def handle_info(:sendback, %{number: number} = state) do
    # here look at the push thing in the website
    {:push, {:text, Msgpax.pack!({"hello", "there"})}, %{state | number: number + 1}}
  end


  def handle_info({:com, command}, state) do
    IO.puts "Received command: #{inspect command}"
    {:push, {:binary, Msgpax.pack!(command)}, state}
  end
    

  def handle_info(m, state) do
    IO.puts "Received default handler message: #{inspect m}"
    {:ok, state}
  end


  def terminate(_reason, _state) do
    :ok
  end

end

