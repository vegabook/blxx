defmodule Blxx.Dag.DagExamples do

  def makefx() do
    {:ok, g} = Blxx.Dag.open_vstore()
    Enum.reduce([:EURPLN, :EURCZK, :USDUSD, :USDGBP, :USDCHF, :USDJPY, 
      :USDSEK, :USDDKK, :USDHUF, :USDRUB, :USDTRY, :USDMXN, :USDZAR, 
      :USDBRL, :USDPLN, :USDCAD, :USDAUD, :USDSGD, :USDHKD, :USDCNY, 
      :USDINR, :USDKRW, :USDIDR, :USDMYR, :USDTHB, :USDPHP, :USDCOP, 
      :USDPEN, :USDCZK, :USDRON, :USDBGN], fn x, g ->
        case Blxx.Dag.store_vertex(g, x, :fx, %{desc: x}) do
          {:ok, g} -> g
          {:error, x} -> IO.inspect {:error, x}
        end
    end)
    Blxx.Dag.close_vstore()
    {:ok, g}
  end

end
