defmodule Blxx.Dag.NodeMaker.Curves do

  # creates nodes for bonds

  defp curve_dir do
    # read the curve directory from the config
    Application.get_env(:blxx, Blxx.Dag)[:nodes_dir]
  end

  defp curve_files do
    # read all the csv files in the curve directory
    curve_dir() 
      |> File.ls!() 
      |> Enum.filter(fn x -> String.ends_with?(x, ".csv") end)
      |> Enum.map(fn x -> Path.join(curve_dir(), x) end)
      |> Enum.map(fn x -> Path.expand(x) end)
  end

  defp curve_names(curve_files) do
    # curve names from files
    curve_files
      |> Enum.map(fn x -> Path.basename(x, ".csv") end)
  end

  defp file_streams(curve_files) do
    # csv list
    data = curve_files |> Enum.map(fn cfile -> 
      cfile
        |> File.stream!
        |> CSV.decode!
        |> Enum.to_list
    end)
  end

  defp curve_streams(file_streams) do
    # add header and create keyword lists
    file_streams |> Enum.map(fn fs -> 
      [header | lines] = fs
      header_atom = Enum.map(header, fn x -> String.to_atom(x) end)
      Enum.map(lines, fn line -> Enum.zip(header_atom, line) end)
    end)
  end

  defp fix_date(bond_keyword_list) do
    # change from american to european date mm/dd/yyyy to yyyy/mm/dd
    issue_dt = Keyword.get(bond_keyword_list, :ISSUE_DT) 
      |> Blxx.Util.us_string_to_datetime
    maturity_dt = Keyword.get(bond_keyword_list, :MATURITY_DT)
      |> Blxx.Util.us_string_to_datetime
    Keyword.put(bond_keyword_list, :ISSUE_DT, issue_dt)
      |> Keyword.put(:MATURITY_DT, maturity_dt)
  end
  
  @doc """
  return a list of tuples of curve names and their data from the csv files
  """
  def curves do
    cf = curve_files()
    curve_ids = cf |> curve_names |> Enum.map(fn x -> String.to_atom(x) end)
    Enum.zip(curve_ids, curve_files() 
      |> file_streams 
      |> curve_streams 
      |> IO.inspect()
      |> Enum.map(fn x -> Enum.map(x, &fix_date/1) end))
  end

end
