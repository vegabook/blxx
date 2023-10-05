defmodule Blxx.Tick do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tick" do
    field :source, :string
    field :fld, :string
    field :value, :float
    field :timestamp, :utc_datetime
    belongs_to :topic, Blxx.Topic

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(tick, params \\ %{}) do
    tick
    |> cast(params, [:source, :topic, :fld, :value, :timestamp])
    |> validate_required([:source, :topic, :fld, :value, :timestamp])
  end

end

