defmodule OrgNotes.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), primary_key: true
      add :theme, :string, default: "light"
      add :language, :string, default: "en"
      add :timezone, :string, default: "UTC"
      add :default_organization, :string, default: "weekday"
      add :default_filters, :map, default: %{}
      add :saved_view_states, {:array, :map}, default: []
      add :email_notifications, :boolean, default: true
      add :desktop_notifications, :boolean, default: false

      timestamps()
    end
  end
end
