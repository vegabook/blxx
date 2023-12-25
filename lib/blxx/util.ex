defmodule Blxx.Util do
  @moduledoc """
  Utility functions for Blxx
  """
  def utc_stamp() do
    DateTime.utc_now() |> DateTime.to_unix(:microsecond)
  end

  def random_string(length \\ 8) do
    #:crypto.strong_rand_bytes(length) |> Base.url_encode64()
    for _ <- 1..length, into: "", do: <<Enum.random('1234567890')>>
  end
end
