defmodule Blxx.Util do
  @moduledoc """
  Utility functions for Blxx
  """
  def utc_stamp() do
    DateTime.utc_now() |> DateTime.to_unix(:microsecond)

  end
end
