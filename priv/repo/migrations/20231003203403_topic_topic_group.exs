defmodule Blxx.Repo.Migrations.TopicTopicGroup do
  use Ecto.Migration

  def change do
    create table(:topic_topic_group, primary_key: false) do
      add :topic_group_id, references(:topic_group, on_delete: :nothing)
      add :topic_id, references(:topic, on_delete: :nothing)
    end

    create index(:topic_topic_group, [:topic_group_id])
    create index(:topic_topic_group, [:topic_id])


  end
end
