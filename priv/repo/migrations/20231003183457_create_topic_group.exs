defmodule Blxx.Repo.Migrations.CreateTopicGroup do
  use Ecto.Migration

  def change do
    create table(:topic_group) do
      add :name, :string
      add :subscribe, :boolean
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:topic_group, [:name], unique: true)
    create index(:topic_group, [:subscribe])

  end
end
