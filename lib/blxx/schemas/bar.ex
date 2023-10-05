defmodule Blxx.Bar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bar" do
    field :source, :string
    field :msgtype, :string
    field :interval, :integer
    field :numticks, :integer
    field :open, :float, default: nil
    field :high, :float, default: nil
    field :low, :float, default: nil
    field :close, :float, default: nil
    field :volume, :integer
    field :timestamp, :utc_datetime
    belongs_to :topic, Blxx.Topic

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(tick, params \\ %{}) do
    tick
    |> cast(params, [:source, :topic, :interval, :numticks, 
      :open, :high, :low, :close, :volume, :timestamp])
    |> validate_required([:source, :topic, :timestamp]) 
    
  end

end

