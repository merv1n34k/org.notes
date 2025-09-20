defmodule OrgNotes.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string, null: false
      add :avatar_url, :text
      add :provider, :string, null: false
      add :provider_id, :string, null: false
      add :role, :string, null: false, default: "user"
      add :is_active, :boolean, default: true
      add :last_login_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:provider, :provider_id])
  end
end
