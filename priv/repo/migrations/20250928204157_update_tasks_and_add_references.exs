defmodule OrgNotes.Repo.Migrations.UpdateTasksAndAddReferences do
  use Ecto.Migration

  def change do
    # Drop task_members table
    drop table(:task_members)

    # Update tasks table
    rename table(:tasks), :created_by_id, to: :owner_id
    alter table(:tasks) do
      add :unlocked, :boolean, default: false, null: false
    end

    # Create task_reference_items table
    create table(:task_reference_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :referenced_task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create index(:task_reference_items, [:task_id, :position])
    create unique_index(:task_reference_items, [:task_id, :referenced_task_id])
  end
end
