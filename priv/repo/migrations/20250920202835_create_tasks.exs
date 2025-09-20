defmodule OrgNotes.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 500
      add :tags, {:array, :string}, default: []
      add :owner_id, references(:users, type: :binary_id), null: false
      add :status, :string, null: false, default: "active"
      add :completed_at, :utc_datetime
      add :description, :text
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:tasks, [:owner_id, :status])
    create index(:tasks, [:tags], using: :gin)
    create index(:tasks, [:inserted_at])
  end
end
