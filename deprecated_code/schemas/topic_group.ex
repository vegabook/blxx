defmodule Blxx.TopicGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "topic_group" do
    field(:name, :string)
    field(:subscribe, :boolean, default: true)
    field(:metadata, :map)
    many_to_many(:topic, Blxx.Topic, join_through: "topic_topic_group")

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(topic_group, attrs) do
    topic_group
    |> cast(attrs, [:name, :subscribe, :metadata])
    |> validate_required([:name])
  end
end
