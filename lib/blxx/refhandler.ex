defmodule Blxx.RefHandler do
  @moduledoc """
  Specifically for ticks, bars, and daily histories, accumulates
  all packets and returns fully parsed
  """

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end 

  def init(:ok) do

  end

end



