defmodule Blxx.BarHandler do
  @moduledoc """
    handles bars from bloomberg
  """
  use GenStage

  def start_link(params) do
    [ticker, fields | rest] = params
    correlid = {:blp, :barsubscribe, ticker} # TODO check
    {:ok, correlid} = GenStage.start_link(__MODULE__, [ticker, fields, rest]), 
      name: {via: Blxx.Registry, correl_id})
  end

  def init(state) do
    send(sockpid(), {:com, ["BarSubscribe", [ticker, fields] ++ options]})
    {:producer, state}
  end

  def handle_cast({:incoming, inbar}, state) do
    IO.puts "inside handle_cast for incoming bar"
    require IEx; IEx.pry
  end



end
