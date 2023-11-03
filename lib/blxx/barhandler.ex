defmodule Blxx.BarHandler do
  @moduledoc """
    handles bars from bloomberg
  """
  #use GenStage
  alias Blxx.Com

  def start_link([ticker, fields | rest]) do
    correlid = {:blp, :barsubscribe, ticker}
    GenStage.start_link(__MODULE__, [ticker, fields, rest],
      name: {:via, Blxx.Registry, correlid})
  end

  
  def init(state) do
    [ticker, fields | options] = state
    IO.puts "in init of barhandler"

    send(Com.sockpid(), {:com, ["BarSubscribe", [ticker, fields] ++ options]})
    {:producer, state}
  end


  def handle_cast({:incoming, inbar}, state) do
    IO.puts "inside handle_cast for incoming bar"
    require IEx; IEx.pry
  end

  def handle_demand(demand, state) do
    IO.puts "inside handle_demand"
    {:noreply, [], state}
  end


end
