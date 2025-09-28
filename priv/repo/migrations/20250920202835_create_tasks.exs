defmodule OrgNotes.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 500
      add :tags, {:array, :string}, default: []
      add :state, :string, null: false, default: "active"
      add :created_by_id, references(:users, type: :binary_id), null: false
      add :modified_by_id, references(:users, type: :binary_id), null: false
      add :modified_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:tasks, [:created_by_id, :state])
    create index(:tasks, [:tags], using: :gin)
    create index(:tasks, [:inserted_at])
    create index(:tasks, [:modified_at])
  end
end
