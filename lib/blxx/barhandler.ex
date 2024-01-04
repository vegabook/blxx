defmodule Blxx.BarHandler do
  @moduledoc """
    handles bars from bloomberg
  """

  use GenServer

  def start_link([ticker, fields | rest]) do
    IO.puts("in start_link of barhandler")
    correlid = {:blp, :barsubscribe, ticker} # TODO this should be specified by the supervisor and should be from dag
    GenStage.start_link(__MODULE__, [ticker, fields, rest], name: {:via, Blxx.Registry, correlid})
  end

  def init(state) do
    [ticker, fields | options] = state
    IO.puts("in init of barhandler")
    send(Blxx.Com.sockpid(), {:com, ["BarSubscribe", [ticker, fields] ++ options]})
    {:producer, state}
  end

  def handle_cast({:incoming, inbar}, state) do
    IO.puts("inside handle_cast for incoming bar")
    require IEx
    IEx.pry()
  end

  def handle_demand(_demand, state) do
    IO.puts("inside handle_demand")
    {:noreply, [], state}
  end
end
