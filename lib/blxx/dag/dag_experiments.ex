defmodule Blxx.Dag.DagExperiments do

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
    Blxx.Dag.add_vertex({d, g}, :a, :root, %{a: "a"})
    Blxx.Dag.add_vertex({d, g}, :b)
    Blxx.Dag.add_vertex({d, g}, :c, :root, %{oui: "dacord", la: %{"un" =>  1}})
    Blxx.Dag.add_vertex({d, g}, :d, :a, %{a: "b"})
    Blxx.Dag.add_vertex({d, g}, :e, :a)
    Blxx.Dag.add_vertex({d, g}, :f, :a)
    Blxx.Dag.add_vertex({d, g}, :g, :b)
    Blxx.Dag.add_vertex({d, g}, :h, :b)
    Blxx.Dag.add_vertex({d, g}, :i, :b)
    Blxx.Dag.add_vertex({d, g}, :j, :c, %{yes: "okay", la: %{"deux" => 2}})
    Blxx.Dag.add_vertex({d, g}, :k, :c)
    Blxx.Dag.add_vertex({d, g}, :l, :c)
    Blxx.Dag.add_vertex({d, g}, :m, :d)
    Blxx.Dag.add_vertex({d, g}, :n, :d)
    Blxx.Dag.add_vertex({d, g}, :o, :e)
    Blxx.Dag.add_vertex({d, g}, :p, :e)
    Blxx.Dag.add_vertex({d, g}, :q, :f)
    Blxx.Dag.add_vertex({d, g}, :r, :f)
    Blxx.Dag.add_vertex({d, g}, :s, :g)
    Blxx.Dag.add_vertex({d, g}, :t, :g)
    Blxx.Dag.add_vertex({d, g}, :u, :h)
    Blxx.Dag.add_vertex({d, g}, :v, :h)
    Blxx.Dag.add_vertex({d, g}, :w, :i)
    Blxx.Dag.add_vertex({d, g}, :x, :i)
    Blxx.Dag.add_vertex({d, g}, :y, :j)
    Blxx.Dag.add_vertex({d, g}, :z, :j)
    {d, g}
  end

  def fx() do
    {:ok, {d, g}, f} = fileman()

    dev = [
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

    emea = [
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

    asia = [
      :USDCNY,
      :USDINR,
      :USDKRW,
      :USDIDR,
      :USDMYR,
      :USDTHB,
      :USDPHP,
    ]

    latam = [
      :USDMXN,
      :USDBRL,
      :USDCOP,
      :USDPEN,
      :USDCLP,
    ]

    Blxx.Dag.add_vertex({d, g}, :fx, :root, %{:asset_class => "foreign exchange", subscribe: true})
    Blxx.Dag.add_vertex({d, g}, :dev, :fx, %{:desc => "developed"})
    Blxx.Dag.add_vertex({d, g}, :emea, :fx, %{:desc => "europe, middle east, africa"})
    Blxx.Dag.add_vertex({d, g}, :asia, :fx, %{:desc => "asia"})
    Blxx.Dag.add_vertex({d, g}, :latam, :fx, %{:desc => "latin america"})
    Blxx.Dag.add_vertices({d, g}, dev, :dev, fn x -> %{:source => :blp, 
      :ticker => to_string(x) <> " Curncy"} end)
    Blxx.Dag.add_vertices({d, g}, emea, :emea, fn x -> %{:source => :blp, 
      :ticker => to_string(x) <> " Curncy"} end)
    Blxx.Dag.add_vertices({d, g}, asia, :asia, fn x -> %{:source => :blp, 
      :ticker => to_string(x) <> " Curncy"} end)
    Blxx.Dag.add_vertices({d, g}, latam, :latam, fn x -> %{:source => :blp, 
      :ticker => to_string(x) <> " Curncy"} end)
    Blxx.Dag.add_vertex({d, g}, :USDBRL, :latam, %{desc: :this_is_new_meta})
    {d, g}

  end


end
