defmodule Blxx.RefHandler do
  @moduledoc """
  Specifically for ticks, bars, and daily histories, accumulates
  all packets and returns fully parsed
  """


  @ms_timeout 5000

  use GenServer

  def start_link(initial_state \\ []) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(state) do
    state = %{
      cid_map: %{}, 
      timeout: System.monotonic_time(:millisecond) + @ms_timeout
    }
    Process.send_after(self(), :check_timer, @ms_timeout)
    {:ok, state}
  end


  @doc """ 
  prepare data structures for a new incoming request. 
  """
  def handle_call({:incoming, cid}, _from, state) do
    newstate = Kernel.put_in(state, [:cid_map, cid], [])
    {:reply, :ok, newstate}
  end


  @doc """
  insert data into the cid_map, advance timer
  """
  def handle_cast({:insert, message}, _from, state) do
    data = Msgpax.unpack!(message) # NOTE spawn here?

    %{
      "cid" => cid,
      "data" => data, 
      "partial" => partial
    } = data
    
    # insert the data into the correct place
    newstate = 
      Kernel.put_in(state, [:cid_map, cid], [data | state[:cid_map][cid]]) 
      |> Kernel.put(state, :timeout, System.monotonic_time(:millisecond) + @ms_timeout)

    if partial == false do   # if this is the last packet
      Process.send(self(), {:complete, cid})
    end

    {:noreply, newstate}
  end


  @doc """
  Reference data is sometimes composed of multiple packets, so we need to
  check iif the reference data is complete, and if so send it to the database
  """
  def handle_info({:complete, cid}, state) do
    newtime = System.monotonic_time(:millisecond) + @ms_timeout
    Process.send_after(self(), :timeout, @ms_timeout)
    # TODO now send that cid's data to the Blxx.Database
    {:noreply, Map.put(state, :timeout, newtime)} 
  end


  @doc """
  periodically check if timer has expired, if we're still waiting for data
  """
  def handle_info(:check_timer, state) do
    Process.send_after(self(), :check_timer, @ms_timeout) # recall later

    if map_size(state[:cid_map]) > 0 do
      if System.monotonic_time(:millisecond) > state[:timeout] do
        # Log a warning
        IO.puts "WARNING: Reference data timeout NOTE log"
      end
    end

    newtime = System.monotonic_time(:millisecond) + @ms_timeout
    {:noreply, Map.put(state, :timeout, newtime)} 
  end

end
