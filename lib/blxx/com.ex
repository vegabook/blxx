defmodule Blxx.Com do
  @moduledoc """

  Example commands: 
  phttps://keyring.readthedocs.io/en/stable/arses commands and sends them to bloomberg socket
  Blxx.Com.com({:blp, ["HistoricalDataRequest", "info"]})
  Blxx.Com.com({:blp, ["HistoricalDataRequest", %{"securities" => ["USDZAR Curncy"], 
  "  fields" => ["PX_BID"], "startDate" =>"20000101", "endDate" => "20231030"}]})
  Blxx.Com.com({:blp, ["IntradayTickRequest", %{"security" => "USDZAR Curncy", 
    "startDateTime" => DateTime.new!(~D[2023-10-23], ~T[00:00:00]), 
    "endDateTime" => DateTime.new!(~D[2023-10-30], ~T[00:00:00]), "eventTypes" => ["TRADE"]}]})

  eventTypes:
  TRADE
  BID
  ASK
  BID_BEST
  ASK_BEST
  BID_YIELD
  ASK_YIELD
  MID_PRICE
  AT_TRADE
  BEST_BID
  BEST_ASK
  SETTLE
  """
  # --------- communications and sockets ----------

  # MAIN TODO
  # 1. create a disk based dag for FX
  # 2. create barsubscibe for any node in the dag
  # 3. use dynamic supervisor launch barsubscribe genservers
  # 4. only the barsubscibe genservers can get history which is specified by timestamp at launch
  # 5. barsubscribe genserver must mark when it cannot get history for a period so that it is not fetched again
  # 6. barsubscribe genserver must populate a stream for the node. 
  # 7. q. what if multiple barsubscribes of inner nodes subscribe to same leaf topic? Share?

  def sockpid() do
    Registry.lookup(Blxx.Registry, :bbgsocket_pid)
    |> List.first()
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
    # TODO possibly just move this into barSusbscribe
    # TODO can only subscribe to something that is in the dag tree but also implement a raw command
    # TODO send cid which is the dag tree node, to the DynSupervisor

    # insert with here to be sure it works for example: 
    # with true <- Enum.all?(params, fn p -> is_list(p) end),
    #  true <- Map.has_key?(params, "Interval") end) do
    # Enum.map(tickers, fn ticker -> DynSupervisor.start_barhandler([ticker, fields] ++ options) end)
    Enum.map(tickers, fn ticker -> Blxx.DynSupervisor.start_barhandler([ticker, fields]) end)
  end

  def com({:blp, command}) do
    # use with statement here maybe TODO for validation?
    send(sockpid(), {:com, command})
    :ok
  end

  def com(bad_command) do
    IO.puts("Unknown command:")
    IO.inspect(bad_command)
    :error
  end


  # --------- subscriptions ----------

  def barSubscribe(params) when is_map(params) do
    oparams = Map.put_new(params, :options, %{})

    with {:has_topics, true} <- {:has_topics, Map.has_key?(oparams, :topics)},
         {:has_fields, false} <- {:has_fields, Map.has_key?(oparams, :fields)},
         {:topics_is_list, true} <- {:topics_is_list, is_list(oparams[:topics])},
         {:options_is_map, true} <- {:options_is_map, is_map(oparams[:options])} do
      cid = Blxx.Util.random_string()
      com({:blp, [:BarSubscribe, Map.put_new(oparams, :fields, ["LAST_PRICE"]), cid]})
    else
      {:has_topics, false} -> {:error, "no topics provided"}
      {:has_fields, true} -> {:error, "barSubscribe does not accept fields"}
      {:topics_is_list, false} -> {:error, "topics must be a list"}
      {:options_is_map, false} -> {:error, "options must be a map"}
    end
  end

  def barSubscribe(params) when not is_map(params) do
    {:error, "barSubscribe expects a map"}
  end

  def unsubscribe(topic) do
    # TODO fix
    com({:blp, "unsubscribe", topic})
  end


  # --------- reference ----------

  def historicalDataRequest(
    # daily data
      securities \\ ["USDZAR Curncy", "EURUSD Curncy"],
      fields \\ ["LAST_PRICE", "PX_BID", "PX_ASK"],
      startDate \\ "20231201",
      endDate \\ Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    ) do
    cid = Blxx.Util.random_string()
    com(
      {:blp,
       [
         "HistoricalDataRequest",
         %{
           "securities" => securities,
           "fields" => fields,
           "startDate" => startDate,
           "endDate" => endDate
         },
       cid 
       ]}
    )
  end


  def intradayTickRequest(
      security \\ "USDZAR Curncy", 
      startDateTime \\ DateTime.new!(~D[2023-10-23], ~T[10:00:00]),
      endDateTime \\ DateTime.new!(~D[2023-10-23], ~T[10:00:05]),
      eventTypes \\ ["TRADE"]
    ) do
    cid = Blxx.Util.random_string()
    com(
      {:blp,
       [
         "IntradayTickRequest",
         %{
           "security" => security,
           "startDateTime" => startDateTime,
           "endDateTime" => endDateTime,
           "eventTypes" => eventTypes
         },
         cid
       ]}
    )
  end


  def intradayBarRequest(
      security \\ "XBTUSD Curncy", 
      startDateTime \\ DateTime.new!(~D[2023-10-23], ~T[10:00:00]),
      endDateTime \\ DateTime.new!(~D[2023-10-23], ~T[11:10:00]),
      interval \\ 1
    ) do
    with {:i60, true} <- {:i60, interval >= 1 and interval <= 1440} do
      cid = Blxx.Util.random_string()
      com(
        {:blp,
         [
           "IntradayBarRequest",
           %{
             "security" => security,
             "startDateTime" => startDateTime,
             "endDateTime" => endDateTime,
             "interval" => interval,
             "gapFillInitialBar" => true
           },
         cid
         ]}
      )
    else
      {:i60, false} -> {:error, "interval must be greater than 60 and less than 1440"}
    end
      
  end


  @doc """
    ReferenceDataRequest
    Note overrides are of form [{"fieldId" => "CURVE_DATE", "value" => "20100530"}, ...]
  """
  def referenceDataRequest(
    securities \\ ["R2048 Govt", "R2044 Govt"],
    fields \\ ["LAST_PRICE", "PX_BID", "PX_ASK"],
    overrides \\ []
  ) do
    cid = Blxx.Util.random_string(20)
    # TODO over here send a signal to Blxx.RefHandler to let it know data will come back
    Blxx.DynSupervisor
    com(
      {:blp,
       [
         "ReferenceDataRequest",
         %{
           "securities" => securities,
           "fields" => fields,
           "overrides" => overrides
         },
       cid
       ]}
    )
  end


end
