defmodule OrgNotes.Tasks.TaskMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "task_members" do
    field :can_edit, :boolean, default: false
    field :joined_at, :utc_datetime

    belongs_to :task, OrgNotes.Tasks.Task, primary_key: true
    belongs_to :user, OrgNotes.Accounts.User, primary_key: true
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:task_id, :user_id, :can_edit, :joined_at])
    |> validate_required([:task_id, :user_id])
    |> put_joined_at()
    |> unique_constraint([:task_id, :user_id])
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:user_id)
  end

  defp put_joined_at(changeset) do
    if get_change(changeset, :joined_at) do
      changeset
    else
      put_change(changeset, :joined_at, DateTime.truncate(DateTime.utc_now(), :second))
    end
  end
end
