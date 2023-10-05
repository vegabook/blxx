defmodule Blxx.Repo.Migrations.CreateBar do
  use Ecto.Migration

  def change do
    create table(:bar) do
      add :source, :string
      add :topic_id, references(:topic, on_delete: :nothing)
      add :interval, :integer
      add :numticks, :integer
      add :open, :float
      add :high, :float
      add :low, :float
      add :close, :float
      add :volume, :integer
      add :timestamp, :utc_datetime
      add :msgtype, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:bar, [:topic_id, :source, :interval, :msgtype])
    create index(:bar, [:timestamp])
    create index(:bar, [:topic_id])

  end
end
