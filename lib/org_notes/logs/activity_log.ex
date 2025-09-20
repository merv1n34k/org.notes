defmodule OrgNotes.Logs.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "activity_logs" do
    field :action, :string
    field :changes, :map, default: %{}
    field :ip_address, :string

    belongs_to :user, OrgNotes.Accounts.User
    belongs_to :task, OrgNotes.Tasks.Task

    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :changes, :ip_address, :user_id, :task_id])
    |> validate_required([:action])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:task_id)
  end
end
