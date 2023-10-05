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

  @encrypt_decrypt_opts [rsa_padding: :rsa_pkcs1_oaep_padding]

  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: %{"id" => id}}) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    IO.puts "ID connected: #{id}"
    {:ok, %{number: 1}} # = {:ok, state} else {:error, :unauthorized}
  end

  def init(state) do
    # Now we are effectively inside the process that maintains the socket.
    IO.inspect self()
    #send(self(), :sendback)
    # use the Registry to register the pid
    Registry.register(Blxx.Registry, :bbgsocket_pid, self())
    {:ok, state}
  end

  def handle_in(["key", key], state) do
    IO.puts "Received key: #{inspect key}"
    # generate random bytes
    #challenge = :crypto.strong_rand_bytes(256)
    # encrypt the challenge with the key
    # encrypted_challenge = :crypto.block_encrypt(:aes_cbc256, key, challenge)
    {:ok, key_der} = :public_key.pem_decode(key)
    public_key = :public_key.der_decode(:RSAPublicKey, key_der)
    ciphertext = :public_key.encrypt(:rsa_pkcs1_padding, public_key, "hello")
    IO.inspect ciphertext

    {:noreply, state}
  end

  def handle_in({data, _opts}, state) do
    d = Msgpax.unpack!(data)
    case d do

      %{"subdata" => %{"timestamp" => timestamp,
        "topic" => topic,
        "prices" => prices}} ->
          for %{"field" => field, "value" => value} <- prices do
            %Tick{source: "bbg", topic: topic, fld: field, value: value, timestamp: timestamp}
            |> Tick.changeset
            |> Repo.insert
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
          |> Bar.changeset
          |> Repo.insert  

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

