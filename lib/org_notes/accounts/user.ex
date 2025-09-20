defmodule OrgNotes.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :provider, :string
    field :provider_id, :string
    field :role, :string, default: "user"
    field :is_active, :boolean, default: true
    field :last_login_at, :utc_datetime

    has_one :preferences, OrgNotes.Accounts.UserPreference
    has_many :tasks, OrgNotes.Tasks.Task, foreign_key: :owner_id
    has_many :task_memberships, OrgNotes.Tasks.TaskMember
    has_many :shared_tasks, through: [:task_memberships, :task]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :provider, :provider_id, :role, :is_active, :last_login_at])
    |> validate_required([:email, :name, :provider, :provider_id])
    |> validate_inclusion(:role, ["user", "admin", "super_admin"])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
  end
end
