defmodule BlxxWeb.SubHandler do
  use GenServer

  alias Blxx.Dag
  alias Blxx.DynSupervisor

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, %{}}
  end
end
