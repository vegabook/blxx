defmodule Blxx.Com do
  @moduledoc """
  parses commands and sends them to bloomberg socket
  """

  # TODO
  # subscriptions save to database automatically
  # allow "temporary" subscriptions that don't save to database
  # test subscriptions when first asked to do so
  # generators for subscriptions and their history
  # ticker groups and...
  # ....chain search
  # tickers have metadata in database
  #

  def com({:blp, command}) do
    # use with statement here maybe TODO for validation?
    spid = Registry.lookup(Blxx.Registry, :bbgsocket_pid)
           |> List.first
           |> elem(1)
    send(spid, {:com, command})
    :ok
  end

  @doc """
  subscribe to a topic. 
  """
  def subscribe(topics, source \\ :blp, service \\ :mktdata, 
    type \\:bar, fields \\ ["LAST_PRICE"], interval \\ 1) do
    case type do
      # TODO fix
      :bar -> topic = "//blp/#{service}/#{type}/#{interval}#{topics}"
      :tick -> topic = "//blp/mktdata/isin/US4592001014"
    end 
  end

  def unsubscribe(topic) do
    # TODO fix
    com({:blp, "unsubscribe", topic})
  end
  

  @doc """
  will be called by subscribe to test
  if the subscription works before 
  saving it to database
  """
  def testsubscribe() do
    # TODO
    :ok
  end


  def com(_) do
    IO.puts "Unknown command"
    :error
  end


end

