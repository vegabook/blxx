defmodule Blxx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BlxxWeb.Telemetry,
      # Start the Ecto repository
      Blxx.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Blxx.PubSub},
      # Start Finch
      {Finch, name: Blxx.Finch},
      # Start the Endpoint (http/https)
      BlxxWeb.Endpoint,
      # Start a worker by calling: Blxx.Worker.start_link(arg)
      # {Blxx.Worker, arg}
      # Start the Registry
      {Registry, keys: :unique, name: Blxx.Registry},
      # start the database
      {Blxx.Database, name: Database},
      # start the refhandler
      {Blxx.RefHandler, name: RefHandler},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blxx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlxxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
