defmodule OrgNotes.Tasks.ChecklistItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "checklist_items" do
    field :content, :string
    field :completed, :boolean, default: false
    field :completed_at, :utc_datetime
    field :position, :integer, default: 0

    belongs_to :task, OrgNotes.Tasks.Task
    belongs_to :referenced_task, OrgNotes.Tasks.Task
    belongs_to :completed_by, OrgNotes.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:content, :completed, :completed_at, :position, :task_id,
                    :referenced_task_id, :completed_by_id])
    |> validate_required([:content, :task_id])
    |> validate_length(:content, max: 1000)
    |> validate_position()
    |> maybe_set_reference_position()
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:referenced_task_id)
    |> foreign_key_constraint(:completed_by_id)
  end

  defp validate_position(changeset) do
    changeset
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end

  defp maybe_set_reference_position(changeset) do
    case get_change(changeset, :referenced_task_id) do
      nil -> changeset
      _ ->
        position = get_field(changeset, :position)
        if position < 1000 do
          put_change(changeset, :position, 1000 + position)
        else
          changeset
        end
    end
  end
end
