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

  @doc """
  Checks the message type and takes appropriate action
  depending on whether its reference or subscription data
  """
  def in_handler(data) do
    # unpack 8 pbyte msgpack size header
    <<header::binary-size(8), message::binary>> = data
    <<msgtype::little-integer-size(64)>> = header

    if msgtype == @resp_ref do
      GenServer.cast(Blxx.RefHandler, {:insert, message})
    else
      # TODO send to subhandler
      GenServer.cast(Blxx.SubHandler, {:insert, message})
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
