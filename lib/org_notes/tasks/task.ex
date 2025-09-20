defmodule OrgNotes.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    field :name, :string
    field :tags, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :completed_at, :utc_datetime
    field :description, :string
    field :metadata, :map, default: %{}

    belongs_to :owner, OrgNotes.Accounts.User
    has_many :checklist_items, OrgNotes.Tasks.ChecklistItem
    has_many :task_members, OrgNotes.Tasks.TaskMember
    has_many :members, through: [:task_members, :user]

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:name, :tags, :status, :completed_at, :description, :metadata, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, max: 500)
    |> validate_inclusion(:status, ["active", "completed", "archived"])
    |> validate_tags()
    |> maybe_set_completed_at()
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

  defp maybe_set_completed_at(changeset) do
    case get_change(changeset, :status) do
      "completed" ->
        put_change(changeset, :completed_at, DateTime.utc_now())
      _ ->
        changeset
    end
  end
end
