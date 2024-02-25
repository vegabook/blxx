defmodule Blxx.Source do
  @moduledoc """
  Behaviours for all source modules
  """
  require Logger

  @callback meta(leafnode :: atom, source :: atom, meta :: map) :: :ok | {:error, term}
  @callback test_sub(source :: atom, meta :: map) :: :ok | {:error, term} 

  end
