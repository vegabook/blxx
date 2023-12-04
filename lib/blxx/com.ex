defmodule Blxx.Com do
  @moduledoc """

  Example commands: 
  phttps://keyring.readthedocs.io/en/stable/arses commands and sends them to bloomberg socket
  Blxx.Com.com({:blp, [:barsubscribe, [["EURUSD Curncy", "USDZAR Curncy", "R186 Govt", "SPX Index", "GLE FP Equity", "USDJPY Curncy", "GBPUSD Curncy", "BTC Curncy", "EURCZK Curncy", "USDMXN Curncy", "R2048 Govt", "R2048 Govt"], ["LAST_PRICE"], ["interval=1"]]]})
  Blxx.Com.com({:blp, [:barsubscribe, ["USDMXN Curncy"], ["LAST_PRICE"], ["interval=1"]]]})
  Blxx.Com.com({:blp, [:barsubscribe, [["EURUSD Curncy", "USDZAR Curncy", "R186 Govt", "SPX Index", "GLE FP Equity", "USDJPY Curncy", "GBPUSD Curncy", "BTC Curncy", "EURCZK Curncy", "USDMXN Curncy", "R2048 Govt", "R2048 Govt"], ["LAST_PRICE"], ["interval=1"]]]})
  Blxx.Com.com({:blp, ["HistoricalDataRequest", "info"]})
  Blxx.Com.com({:blp, ["HistoricalDataRequest", %{"securities" => ["USDZAR Curncy"], "fields" => ["PX_BID"], "startDate" =>"20000101", "endDate" => "20231030"}]})
  Blxx.Com.com({:blp, ["IntradayTickRequest", %{"security" => "USDZAR Curncy", "startDateTime" => DateTime.new!(~D[2023-10-23], ~T[00:00:00]), "endDateTime" => DateTime.new!(~D[2023-10-30], ~T[00:00:00]), "eventTypes" => ["TRADE"]}]})
  """

  def sockpid() do
    Registry.lookup(Blxx.Registry, :bbgsocket_pid)
    |> List.first
    |> elem(1)
  end


  # TODO
  #  create processes for each tickers
  # register the processes so that they will get messages for that correlation IDs
  # use dynamic supervisor to monitor these processes
  # each process must self-monitor that it's still getting data 
  # generate a basic tree if more than one tickers is sent
  # Should user provide a name? Probably should force a name requirement
  #       if more than one tickers
  # use logger for all communications
  # implement "raw" command
  def com({:blp, [:barsubscribe, %{tickers: tickers, fields: fields} = params]}) do
    # TODO NB this is messy. Does the syntax work? Also single barhandler best.
    # insert with here to be sure it works for example: 
    #with true <- Enum.all?(params, fn p -> is_list(p) end),
    #  true <- Map.has_key?(params, "Interval") end) do
    #Enum.map(tickers, fn ticker -> DynSupervisor.start_barhandler([ticker, fields] ++ options) end)
    Enum.map(tickers, fn ticker -> DynSupervisor.start_barhandler([ticker, fields]) end)
  end

  def com({:blp, command}) do 
    # use with statement here maybe TODO for validation?
    send(sockpid(), {:com, command})
    :ok
  end

  def com({:blp, command}) do 
    # use with statement here maybe TODO for validation?
    send(sockpid(), {:com, command})
    :ok
  end


  def historical_data_request(securities \\ ["USDZAR Curncy", "EURUSD Curncy"], 
    fields \\ ["LAST_PRICE", "PX_BID", "PX_ASK"], 
    startDate \\ "20000101", 
    endDate \\ Date.utc_today() |> Date.to_string() |> String.replace("-", "")) do
      com({:blp, ["HistoricalDataRequest", 
        %{"securities" => securities, 
          "fields" => fields, 
          "startDate" => startDate, 
          "endDate" => endDate}]})
  end


  def bar_subscribe(topics, source \\ :blp, service \\ :mktdata, 
    fields \\ ["LAST_PRICE", "LAST_TRADE_ACTUAL"], 
    interval \\ 1) do
    # TODO implement "with" validation
    # TODO check of not already subscribed
    # TODO see what happens if subscribing to same ticker but new field. Does bloomberg send new fields in same messages?
    fields_str = Enum.join(fields, ",")
    topic_str_list = Enum.map(topics, fn ticker -> 
      "//blp/mktdata/#{ticker}?fields=#{fields_str}&interval=#{interval}" end)
    IO.inspect topic_str_list
    # TODO register a process for each topic through the registry using topic string as key
    # TODO ets table or cachex for topic strings that are live
    # TODO use dynamic supervisor to monitor these processes
  end


  def unsubscribe(topic) do
    # TODO fix
    com({:blp, "unsubscribe", topic})
  end


  def com(bad_command) do
    IO.puts "Unknown command:"
    IO.inspect bad_command
    :error
  end

end

