defmodule Blxx.Dag.DagExperiments do
# colorscheme moonlight


  def fileman(
        name \\ (Blxx.Util.utc_stamp() |> to_string) <> ".dets",
        dir \\ "/tmp"
      ) do
    filepath =
      Path.join(dir, name)
      |> Path.expand()
      |> to_charlist()

    {:ok, {d, g}} = Blxx.Dag.open_store(filepath)
    {:ok, {d, g}, filepath}
  end


  def bigdag() do
    {:ok, {d, g}, f} = fileman()
    [Blxx.Dag.make_vertex(:a, :root, %{a: "a"}),
     Blxx.Dag.make_vertex(:b),
     Blxx.Dag.make_vertex(:c, :root, %{oui: "dacord", la: %{"un" =>  1}}),
     Blxx.Dag.make_vertex(:d, :a, %{a: "b"}),
     Blxx.Dag.make_vertex(:e, :a),
     Blxx.Dag.make_vertex(:f, :a),
     Blxx.Dag.make_vertex(:g, :b),
     Blxx.Dag.make_vertex(:h, :b),
     Blxx.Dag.make_vertex(:i, :b),
     Blxx.Dag.make_vertex(:j, :c, %{yes: "okay", la: %{"deux" => 2}}),
     Blxx.Dag.make_vertex(:k, :c),
     Blxx.Dag.make_vertex(:l, :c),
     Blxx.Dag.make_vertex(:m, :d),
     Blxx.Dag.make_vertex(:n, :d),
     Blxx.Dag.make_vertex(:o, :e),
     Blxx.Dag.make_vertex(:p, :e),
     Blxx.Dag.make_vertex(:q, :f),
     Blxx.Dag.make_vertex(:r, :f),
     Blxx.Dag.make_vertex(:s, :g),
     Blxx.Dag.make_vertex(:t, :g),
     Blxx.Dag.make_vertex(:u, :h),
     Blxx.Dag.make_vertex(:v, :h),
     Blxx.Dag.make_vertex(:w, :i),
     Blxx.Dag.make_vertex(:x, :i),
     Blxx.Dag.make_vertex(:y, :j),
     Blxx.Dag.make_vertex(:z, :j)] 
    |> IO.inspect() 
    |> Blxx.Dag.commit(d, g)
  end

  def fx() do
    {:ok, {d, g}, f} = fileman()

    devlist = [
      :USDGBP,
      :USDCHF,
      :USDCAD,
      :USDJPY,
      :USDSEK,
      :USDDKK,
      :USDAUD,
      :USDSGD,
      :USDHKD,
    ]

    emealist = [
      :EURHUF,
      :USDRUB,
      :USDTRY,
      :USDZAR,
      :EURRON,
      :EURBGN,
      :EURPLN,
      :EURCZK,
      :USDSAR,
      :USDAED,
    ]

    asialist = [
      :USDCNY,
      :USDINR,
      :USDKRW,
      :USDIDR,
      :USDMYR,
      :USDTHB,
      :USDPHP,
    ]

    latamlist = [
      :USDMXN,
      :USDBRL,
      :USDCOP,
      :USDPEN,
      :USDCLP,
    ]
    
    {:ok, g} = 
      [Blxx.Dag.make_vertex(:fx, :root, %{:asset_class => "foreign exchange", subscribe: true}),
       Blxx.Dag.make_vertex(:dev, :fx, %{:desc => "developed"}),
       Blxx.Dag.make_vertex(:emea, :fx, %{:desc => "europe, middle east, africa"}),
       Blxx.Dag.make_vertex(:asia, :fx, %{:desc => "asia"}),
       Blxx.Dag.make_vertex(:latam, :fx, %{:desc => "latin america"})]
      |> Blxx.Dag.commit(d, g)
    {:ok, g} = 
      Enum.map(devlist, fn x -> Blxx.Dag.make_vertex(x, :dev, %{}) end) 
      |> Blxx.Dag.commit(d, g)
    {:ok, g} = 
      Enum.map(emealist, fn x -> Blxx.Dag.make_vertex(x, :emea, %{}) end) 
      |> Blxx.Dag.commit(d, g)
    {:ok, g} = 
      Enum.map(asialist, fn x -> Blxx.Dag.make_vertex(x, :asia, %{}) end) 
      |> Blxx.Dag.commit(d, g)
    {:ok, g} = 
      Enum.map(latamlist, fn x -> Blxx.Dag.make_vertex(x, :latam, %{}) end) 
      |> Blxx.Dag.commit(d, g)
    {:ok, {d, g}, f}
  end

  def fx_with_sources do
    # add a :blp source node and link it to all the fx nodes
    {:ok, {d, g}, f} = fx()
    Blxx.Dag.add_vertedge({d, g}, :blp, :root, %{:source_name => "bloomberg"})
    Blxx.Dag.add_edge({d, g}, :blp, :USDGBP, %{ticker: "USDGBP Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDCHF, %{ticker: "USDCHF Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDCAD, %{ticker: "USDCAD Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDJPY, %{ticker: "USDJPY Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDSEK, %{ticker: "USDSEK Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDDKK, %{ticker: "USDDKK Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDAUD, %{ticker: "USDAUD Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDSGD, %{ticker: "USDSGD Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDHKD, %{ticker: "USDHKD Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :EURHUF, %{ticker: "EURHUF Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDRUB, %{ticker: "USDRUB Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDTRY, %{ticker: "USDTRY Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDZAR, %{ticker: "USDZAR Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :EURRON, %{ticker: "EURRON Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :EURBGN, %{ticker: "EURBGN Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :EURPLN, %{ticker: "EURPLN Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :EURCZK, %{ticker: "EURCZK Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDSAR, %{ticker: "USDSAR Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDAED, %{ticker: "USDAED Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDCNY, %{ticker: "USDCNY Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDINR, %{ticker: "USDINR Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDKRW, %{ticker: "USDKRW Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDIDR, %{ticker: "USDIDR Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDMYR, %{ticker: "USDMYR Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDTHB, %{ticker: "USDTHB Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDPHP, %{ticker: "USDPHP Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDMXN, %{ticker: "USDMXN Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDBRL, %{ticker: "USDBRL Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDCOP, %{ticker: "USDCOP Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDPEN, %{ticker: "USDPEN Curncy", fields: ["LAST_PRICE"]})
    Blxx.Dag.add_edge({d, g}, :blp, :USDCLP, %{ticker: "USDCLP Curncy", fields: ["LAST_PRICE"]})
    {:ok, {d, g}, f}
  end

  def fx_change_source do
    {:ok, {d, g}, f} = fx_with_sources()
    Blxx.Dag.add_edge({d, g}, :blp, :USDGBP, %{ticker: "USDGBP Curncy", fields: ["BID", "ASK"]})
    {:ok, {d, g}, f}

  end

end
