defmodule OrgNotes.Tasks.ChecklistItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "checklist_items" do
    field :content, :string
    field :state, :string, default: "pending"
    field :position, :integer, default: 0
    field :modified_at, :utc_datetime

    belongs_to :task, OrgNotes.Tasks.Task
    belongs_to :created_by, OrgNotes.Accounts.User
    belongs_to :modified_by, OrgNotes.Accounts.User

    timestamps()
  end

  def changeset(item, attrs, user_id \\ nil) do
    item
    |> cast(attrs, [:content, :state, :position, :task_id])
    |> validate_required([:content, :task_id])
    |> validate_length(:content, max: 1000)
    |> validate_inclusion(:state, ["pending", "completed"])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> put_audit_fields(user_id, item)
    |> foreign_key_constraint(:task_id)
  end

  defp put_audit_fields(changeset, nil, _item), do: changeset
  defp put_audit_fields(changeset, user_id, %__MODULE__{id: nil}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    changeset
    |> put_change(:created_by_id, user_id)
    |> put_change(:modified_by_id, user_id)
    |> put_change(:modified_at, now)
  end
  defp put_audit_fields(changeset, user_id, _item) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    changeset
    |> put_change(:modified_by_id, user_id)
    |> put_change(:modified_at, now)
  end
end
