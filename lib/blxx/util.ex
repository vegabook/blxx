defmodule Blxx.Util do
  @moduledoc """
  Utility functions for Blxx
  """
  @doc """ 
  return a microsecond unix timestamp
  """
  @amdate ~r/^(0?[1-9]|1[0-2])\/(0?[1-9]|[12][0-9]|3[01])\/(19|20)\d\d$/


  def utc_stamp(stamptime \\ DateTime.utc_now()) do
    stamptime |> DateTime.to_unix(:microsecond)
  end


  @doc """
  is the string of type mm/dd/yyyy. Alows m or d but must be yyyy
  """
  def is_amdate(us_string) do
    Regex.match?(@amdate, us_string)
  end


  @doc """
  given a string in the format "mm/dd/yyyy" return a DateTime
  """
  def us_string_to_datetime(us_string) do
    [m, d, y] = String.split(us_string, "/") |> Enum.map(fn x -> String.to_integer(x) end)
    DateTime.new!(Date.new!(y, m, d), Time.new!(0, 0, 0), "Etc/UTC")
  end

  
  def random_string(length \\ 8) do
    #:crypto.strong_rand_bytes(length) |> Base.url_encode64()
    for _ <- 1..length, into: "", do: <<Enum.random('1234567890')>>
  end

  
  def deep_merge(left, right) do
    # recursively merge two maps
    # https://stackoverflow.com/questions/38864001/elixir-how-to-deep-merge-maps
    Map.merge(left, right, &deep_resolve/3)
  end

  # Key exists in both maps, and both values are maps as well.
  # These can be merged recursively.
  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  # Key exists in both maps, but at least one of the values is
  # NOT a map. We fall back to standard merge behavior, preferring
  # the value on the right.
  defp deep_resolve(_key, _left, right) do
    right
  end


end

