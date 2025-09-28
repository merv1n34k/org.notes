defmodule OrgNotes.Repo.Migrations.CreateChecklistItems do
  use Ecto.Migration

  def change do
    create table(:checklist_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :string, null: false, size: 1000
      add :state, :string, null: false, default: "pending"
      add :position, :integer, null: false, default: 0
      add :created_by_id, references(:users, type: :binary_id), null: false
      add :modified_by_id, references(:users, type: :binary_id), null: false
      add :modified_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:checklist_items, [:task_id, :position])
    create index(:checklist_items, [:modified_at])
  end
end
