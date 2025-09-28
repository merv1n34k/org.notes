defmodule OrgNotes.Tasks.ReferenceItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "task_reference_items" do
    field :position, :integer, default: 0

    belongs_to :task, OrgNotes.Tasks.Task
    belongs_to :referenced_task, OrgNotes.Tasks.Task

    timestamps()
  end

  def changeset(reference, attrs) do
    reference
    |> cast(attrs, [:task_id, :referenced_task_id, :position])
    |> validate_required([:task_id, :referenced_task_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:referenced_task_id)
    |> unique_constraint([:task_id, :referenced_task_id])
    |> validate_not_self_reference()
  end

  defp validate_not_self_reference(changeset) do
    task_id = get_field(changeset, :task_id)
    referenced_task_id = get_field(changeset, :referenced_task_id)

    if task_id && referenced_task_id && task_id == referenced_task_id do
      add_error(changeset, :referenced_task_id, "cannot reference itself")
    else
      changeset
    end
  end
end
