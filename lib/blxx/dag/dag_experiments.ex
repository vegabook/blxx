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
    Blxx.Dag.add_vertedge({d, g}, :a, :root, %{a: "a"})
    Blxx.Dag.add_vertedge({d, g}, :b)
    Blxx.Dag.add_vertedge({d, g}, :c, :root, %{oui: "dacord", la: %{"un" =>  1}})
    Blxx.Dag.add_vertedge({d, g}, :d, :a, %{a: "b"})
    Blxx.Dag.add_vertedge({d, g}, :e, :a)
    Blxx.Dag.add_vertedge({d, g}, :f, :a)
    Blxx.Dag.add_vertedge({d, g}, :g, :b)
    Blxx.Dag.add_vertedge({d, g}, :h, :b)
    Blxx.Dag.add_vertedge({d, g}, :i, :b)
    Blxx.Dag.add_vertedge({d, g}, :j, :c, %{yes: "okay", la: %{"deux" => 2}})
    Blxx.Dag.add_vertedge({d, g}, :k, :c)
    Blxx.Dag.add_vertedge({d, g}, :l, :c)
    Blxx.Dag.add_vertedge({d, g}, :m, :d)
    Blxx.Dag.add_vertedge({d, g}, :n, :d)
    Blxx.Dag.add_vertedge({d, g}, :o, :e)
    Blxx.Dag.add_vertedge({d, g}, :p, :e)
    Blxx.Dag.add_vertedge({d, g}, :q, :f)
    Blxx.Dag.add_vertedge({d, g}, :r, :f)
    Blxx.Dag.add_vertedge({d, g}, :s, :g)
    Blxx.Dag.add_vertedge({d, g}, :t, :g)
    Blxx.Dag.add_vertedge({d, g}, :u, :h)
    Blxx.Dag.add_vertedge({d, g}, :v, :h)
    Blxx.Dag.add_vertedge({d, g}, :w, :i)
    Blxx.Dag.add_vertedge({d, g}, :x, :i)
    Blxx.Dag.add_vertedge({d, g}, :y, :j)
    Blxx.Dag.add_vertedge({d, g}, :z, :j)
    {:ok, {d, g}, f}
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

    Blxx.Dag.add_vertedge({d, g}, :fx, :root, %{:asset_class => "foreign exchange", subscribe: true})
    Blxx.Dag.add_vertedge({d, g}, :dev, :fx, %{:desc => "developed"})
    Blxx.Dag.add_vertedge({d, g}, :emea, :fx, %{:desc => "europe, middle east, africa"})
    Blxx.Dag.add_vertedge({d, g}, :asia, :fx, %{:desc => "asia"})
    Blxx.Dag.add_vertedge({d, g}, :latam, :fx, %{:desc => "latin america"})
    Blxx.Dag.add_vertedges({d, g}, devlist, :dev)
    Blxx.Dag.add_vertedges({d, g}, emealist, :emea)
    Blxx.Dag.add_vertedges({d, g}, asialist, :asia)
    Blxx.Dag.add_vertedges({d, g}, latamlist, :latam)
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
