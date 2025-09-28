defmodule OrgNotes.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    field :name, :string
    field :tags, {:array, :string}, default: []
    field :state, :string, default: "active"
    field :modified_at, :utc_datetime
    field :unlocked, :boolean, default: false

    belongs_to :owner, OrgNotes.Accounts.User
    belongs_to :modified_by, OrgNotes.Accounts.User
    has_many :checklist_items, OrgNotes.Tasks.ChecklistItem
    has_many :task_references, OrgNotes.Tasks.ReferenceItem
    has_many :referenced_tasks, through: [:task_references, :referenced_task]

    timestamps()
  end

  def changeset(task, attrs, user_id \\ nil) do
    task
    |> cast(attrs, [:name, :tags, :state, :unlocked])
    |> validate_required([:name])
    |> validate_length(:name, max: 500)
    |> validate_inclusion(:state, ["active", "completed", "archived"])
    |> validate_tags()
    |> put_audit_fields(user_id, task)
  end

  defp validate_tags(changeset) do
    validate_change(changeset, :tags, fn :tags, tags ->
      if Enum.all?(tags, &is_binary/1) do
        []
      else
        [tags: "all tags must be strings"]
      end
    end)
  end

  defp put_audit_fields(changeset, nil, _task), do: changeset
  defp put_audit_fields(changeset, user_id, %__MODULE__{id: nil}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    changeset
    |> put_change(:owner_id, user_id)
    |> put_change(:modified_by_id, user_id)
    |> put_change(:modified_at, now)
  end
  defp put_audit_fields(changeset, user_id, _task) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    changeset
    |> put_change(:modified_by_id, user_id)
    |> put_change(:modified_at, now)
  end
end
