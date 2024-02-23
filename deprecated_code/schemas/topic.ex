defmodule Blxx.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "topic" do
    field(:name, :string)
    field(:shortname, :string)
    field(:subscribe, :boolean)
    field(:metadata, :map)
    has_many(:bar, Blxx.Bar)
    has_many(:tick, Blxx.Tick)
    many_to_many(:topic_group, Blxx.TopicGroup, join_through: "topic_topic_group")

    timestamps()
  end

  @doc false
  def changeset(tick, params \\ %{}) do
    tick
    |> cast(params, [:name, :shortname, :subscribe, :metadata])
    |> validate_required([:name, :shortname])
  end
end
