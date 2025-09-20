defmodule OrgNotes.Repo.Migrations.CreateTaskMembers do
  use Ecto.Migration

  def change do
    create table(:task_members, primary_key: false) do
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :can_edit, :boolean, default: false
      add :joined_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:task_members, [:task_id])
    create index(:task_members, [:user_id])
    create unique_index(:task_members, [:task_id, :user_id])
  end
end
