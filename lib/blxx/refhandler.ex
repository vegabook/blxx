defmodule Blxx.RefHandler do
  @moduledoc """
  Specifically for ticks, bars, and daily histories, accumulates
  all packets and returns fully parsed
  """

  use GenServer

  def start_link(correlid) do
    GenServer.start_link(__MODULE__, correlid, name: correlid)
  end

  def init(correlid) do
    {:ok, correlid}
  end
end
