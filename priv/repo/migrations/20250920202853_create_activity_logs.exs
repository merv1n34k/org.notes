defmodule OrgNotes.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id)
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all)
      add :action, :string, null: false
      add :changes, :map, default: %{}
      add :ip_address, :inet

      timestamps(updated_at: false)
    end

    create index(:activity_logs, [:user_id])
    create index(:activity_logs, [:task_id, :inserted_at], order: [desc: :inserted_at])
    create index(:activity_logs, [:inserted_at], order: [desc: :inserted_at])
  end
end
