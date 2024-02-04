defmodule Blxx.RefHandler do
  @moduledoc """
  Specifically for ticks, bars, and daily histories, accumulates
  all packets and returns fully parsed
  """

  # TODO move all data out of state and into ETS for better supervisor restart behaviour

  @ms_timeout 5000

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    IO.puts "Starting RefHandler"
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
    IO.puts "Preparing incoming reference data #{cid}"
    newstate = Kernel.put_in(state, [:cid_map, cid], [])
    {:reply, :ok, newstate}
  end


  @doc """
  insert data into the cid_map, advance timer
  """
  def handle_cast({:insert, message}, state) do
    data = Msgpax.unpack!(message) # NOTE spawn here?

    ["refdata", %{
      "cid" => cid,
      "data" => data, 
      "partial" => partial
    }] = data
    
    # insert the data into the correct place
    newstate = 
      Kernel.put_in(state, [:cid_map, cid], [data | state[:cid_map][cid]]) 
      |> Map.put(:timeout, System.monotonic_time(:millisecond) + @ms_timeout)

    if partial == false do   # if this is the last packet
      send(self(), {:complete, cid})
    end
    {:noreply, newstate}
  end


  @doc """
  Reference data is sometimes composed of multiple packets, so we need to
  check iif the reference data is complete, and if so send it to the database
  """
  def handle_info({:complete, cid}, state) do
    # send the data to the database
    IO.puts "Sending complete reference data to database"
    IO.inspect(state[:cid_map][cid])
    #GenServer.cast(Blxx.Database, {:insert, cid, state[:cid_map][cid]})
    Blxx.Database.insert(cid, state[:cid_map][cid])
    new_cid_map = Map.delete(state[:cid_map], cid)
    newtime = System.monotonic_time(:millisecond) + @ms_timeout # update timer
    newstate = %{
      cid_map: new_cid_map, 
      timeout: newtime
    }
    {:noreply, newstate}
  end


  @doc """
  periodically check if timer has expired, if we're still waiting for data
  """
  def handle_info(:check_timer, state) do
    Process.send_after(self(), :check_timer, @ms_timeout) # re schedule
    # if cid_map is not empty, check we've received data before timeout
    if map_size(state[:cid_map]) > 0 do
      if System.monotonic_time(:millisecond) > state[:timeout] do
        # Log a warning
        IO.puts "WARNING: Reference data timeout NOTE log"
      end
    end
    # we've checked already, so reset the timer
    newtime = System.monotonic_time(:millisecond) + @ms_timeout
    {:noreply, Map.put(state, :timeout, newtime)} 
  end


  @doc """
  entirely clear the cid_map. DEBUG only
  """

  def clearqueue do
    GenServer.call(__MODULE__, :clearqueue)
  end

  def handle_call(:clearqueue, _from, state) do
    newstate = Map.put(state, :cid_map, %{})
    {:reply, :ok, newstate}
  end

end
