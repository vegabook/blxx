defmodule Blxx.Repo.Migrations.CreateTick do
  use Ecto.Migration

  def change do
    create table(:tick) do
      add :source, :string
      add :topic_id, references(:topic, on_delete: :nothing)
      add :fld, :string
      add :value, :float
      add :timestamp, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tick, [:topic_id, :source, :fld])
    create index(:tick, [:timestamp])
  end
end
