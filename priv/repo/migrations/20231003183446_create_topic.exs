defmodule Blxx.Repo.Migrations.CreateTopic do
  use Ecto.Migration

  def change do
    create table(:topic) do
      add :name, :string
      add :shortname, :string
      add :subscribe, :boolean
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:topic, [:name], unique: true)
    create index(:topic, [:shortname], unique: true)
    create index(:topic, [:subscribe])

  end
end
