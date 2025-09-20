defmodule OrgNotes.Repo.Migrations.CreateChecklistItems do
  use Ecto.Migration

  def change do
    create table(:checklist_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :string, null: false, size: 1000
      add :referenced_task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :completed, :boolean, default: false
      add :completed_by_id, references(:users, type: :binary_id)
      add :completed_at, :utc_datetime
      add :position, :integer, null: false, default: 0

      timestamps(updated_at: false)
    end

    create index(:checklist_items, [:task_id, :position])
    create index(:checklist_items, [:referenced_task_id], where: "referenced_task_id IS NOT NULL")

    # Add constraint for position ranges
    create constraint(:checklist_items, :check_position,
      check: "(referenced_task_id IS NULL AND position >= 0) OR (referenced_task_id IS NOT NULL AND position >= 1000)")
  end
end
