defmodule Blxx.RefHandler do
  @moduledoc """
  Specifically for ticks, bars, and daily histories, accumulates
  all packets and returns fully parsed
  """

  # TODO this will handle all reference data requests
  # and stick them in the database.
  # must be told about upcoming things to handle by referenceDataRequest, intradayTickRequest, etc.
  # then must track that it receives a "partial = false" message for each one or 
  # time out, but reset timeout time on ANY message received because multiple request responses
  # are received synchronously. 

  @ms_timeout 5000

  use GenServer

  def start_link(istate \\ []) do
    # TODO add a timer here that starts as soon as we get an :incoming, 
    # and if the correl_map is not empty, then this timer constantly gets updated until they're all empty
    # and if it times out check which correls have not completed. 
    GenServer.start_link(__MODULE__, istate)
  end

  def init(state) do
    state = %{correl_map: %{}, timeout: System.monotonic_time(:millisecond) + @ms_timeout}
    {:ok, state}
  end

  def handle_call({:incoming, correlid}, _from, state) do
    Map.put(state[:correl_map], correlid, [])
    {:reply, {:ok, correlid}}
  end


  def handle_cast({:insert, key, value}, _from, correlid) do
    # TODO here spawn a message unpacker for speed
    {:reply, :ok, Map.put(correlid, key, [value | Map.get(correlid, key, [])])}
  end


  def handle_info(:check_timer, state) do
    # TODO check here if stuff needs to be cancelled
    # use this: timer_ref = Process.send_after(self(), :check_timer, @ms_timeout)
    # and this: Process.cancel_timer(timer_ref)

    newtime = System.monotonic_time(:millisecond) + @ms_timeout
    Process.send_after(self(), :check_timer, @ms_timeout)
    {:noreply, Map.put(state, :timeout, newtime)} 
  end

end
