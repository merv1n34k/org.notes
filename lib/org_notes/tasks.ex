defmodule OrgNotes.Tasks do
  import Ecto.Query
  alias OrgNotes.{Repo, Tasks.Task, Tasks.ChecklistItem, Tasks.ReferenceItem}
  alias OrgNotes.ActivityLog
  alias OrgNotesWeb.Endpoint

  # Task CRUD operations
  def get_task!(id) do
    Task
    |> Repo.get!(id)
    |> Repo.preload([:checklist_items, :owner, :modified_by, task_references: :referenced_task])
  end

  def create_task(attrs, user_id, block_id) do
    # Add the block_id as a tag to group tasks by weekday
    current_tags = Map.get(attrs, "tags", [])
    attrs = Map.put(attrs, "tags", [block_id | current_tags])

    result = %Task{}
    |> Task.changeset(attrs, user_id)
    |> Repo.insert()

    case result do
      {:ok, task} ->
        task = Repo.preload(task, [:checklist_items, :owner, :modified_by, :task_references])
        ActivityLog.log(:task_created, %{
          user_id: user_id,
          task_id: task.id,
          task_name: task.name
        })
        broadcast_task_update(task, :created)
        {:ok, task}
      error -> error
    end
  end

  def update_task(%Task{} = task, attrs, user_id) do
    # Check if user can edit (owner or unlocked)
    if task.owner_id == user_id || task.unlocked do
      changeset = Task.changeset(task, attrs, user_id)

      case Repo.update(changeset) do
        {:ok, task} ->
          task = Repo.preload(task, [:checklist_items, :owner, :modified_by, task_references: :referenced_task], force: true)
          ActivityLog.log(:task_updated, %{
            user_id: user_id,
            task_id: task.id,
            changes: changeset.changes
          })
          broadcast_task_update(task, :updated)
          {:ok, task}
        error -> error
      end
    else
      {:error, :unauthorized}
    end
  end

  def delete_task(%Task{} = task, user_id) do
    if task.owner_id == user_id do
      case Repo.delete(task) do
        {:ok, task} ->
          ActivityLog.log(:task_deleted, %{
            user_id: user_id,
            task_id: task.id,
            task_name: task.name
          })
          broadcast_task_update(task, :deleted)
          {:ok, task}
        error -> error
      end
    else
      {:error, :unauthorized}
    end
  end

  def toggle_task_lock(%Task{} = task, user_id) do
    if task.owner_id == user_id do
      attrs = %{"unlocked" => !task.unlocked}
      update_task(task, attrs, user_id)
    else
      {:error, :unauthorized}
    end
  end

  def maybe_auto_complete_task(%Task{} = task, user_id) do
    if length(task.checklist_items) > 0 do
      all_completed = Enum.all?(task.checklist_items, fn item -> item.state == "completed" end)

      new_state = if all_completed, do: "completed", else: "active"

      if task.state != new_state do
        update_task(task, %{"state" => new_state}, user_id)
      end
    end
  end

  # List all tasks (visible to everyone)
  def list_all_tasks do
    from(t in Task,
      where: t.state != "archived",
      order_by: [desc: t.modified_at],
      preload: [:checklist_items, :owner, :modified_by, task_references: :referenced_task]
    )
    |> Repo.all()
  end

  # List tasks for search/reference
  def list_available_tasks(exclude_task_id \\ nil) do
    query = from(t in Task,
      where: t.state == "active",
      order_by: [desc: t.modified_at],
      preload: [:owner]
    )

    query = if exclude_task_id do
      from t in query, where: t.id != ^exclude_task_id
    else
      query
    end

    Repo.all(query)
  end

  def group_tasks_by_weekday(tasks) do
    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    # Group tasks by their weekday tag
    task_groups = Enum.group_by(tasks, fn task ->
      Enum.find(task.tags, fn tag -> tag in days end) || "Sunday"
    end)

    Enum.map(days, fn day ->
      %{
        id: day,
        name: day,
        tasks: Map.get(task_groups, day, [])
      }
    end)
  end

  # Checklist operations
  def get_checklist_item!(id) do
    Repo.get!(ChecklistItem, id)
  end

  def create_checklist_item(task_id, attrs, user_id) do
    task = get_task!(task_id)

    # Anyone can add checklist items
    position = get_next_checklist_position(task_id)
    attrs = Map.put(attrs, "position", position)

    changeset = %ChecklistItem{}
    |> ChecklistItem.changeset(Map.put(attrs, "task_id", task_id), user_id)

    case Repo.insert(changeset) do
      {:ok, item} ->
        ActivityLog.log(:checklist_item_created, %{
          user_id: user_id,
          task_id: task_id,
          checklist_item_id: item.id,
          item: item.content
        })
        task = Repo.preload(task, [:checklist_items, :owner, :modified_by, task_references: :referenced_task], force: true)
        broadcast_task_update(task, :updated)
        {:ok, item}
      error -> error
    end
  end

  def update_checklist_item(item_id, attrs, user_id) do
    item = get_checklist_item!(item_id)
    changeset = ChecklistItem.changeset(item, attrs, user_id)

    case Repo.update(changeset) do
      {:ok, item} ->
        task = get_task!(item.task_id)
        broadcast_task_update(task, :updated)
        {:ok, item}
      error -> error
    end
  end

  def delete_checklist_item(item_id, user_id) do
    item = get_checklist_item!(item_id)

    case Repo.delete(item) do
      {:ok, item} ->
        ActivityLog.log(:checklist_item_deleted, %{
          user_id: user_id,
          task_id: item.task_id,
          checklist_item_id: item.id,
          item: item.content
        })
        task = get_task!(item.task_id)
        maybe_auto_complete_task(task, user_id)
        broadcast_task_update(task, :updated)
        {:ok, item}
      error -> error
    end
  end

  def toggle_checklist_item(item_id, user_id) do
    item = Repo.get!(ChecklistItem, item_id)
    |> Repo.preload(:task)

    new_state = if item.state == "completed", do: "pending", else: "completed"

    changeset = ChecklistItem.changeset(item, %{"state" => new_state}, user_id)

    case Repo.update(changeset) do
      {:ok, item} ->
        ActivityLog.log(:checklist_toggled, %{
          user_id: user_id,
          task_id: item.task_id,
          checklist_item_id: item.id,
          item: item.content,
          state: item.state
        })

        task = get_task!(item.task_id)
        broadcast_task_update(task, :updated)
        {:ok, item}
      error -> error
    end
  end

  # Reference operations
  def create_task_reference(task_id, referenced_task_id, user_id) do
    task = get_task!(task_id)

    # Check if user can edit
    if task.owner_id == user_id || task.unlocked do
      position = get_next_reference_position(task_id)

      changeset = %ReferenceItem{}
      |> ReferenceItem.changeset(%{
        "task_id" => task_id,
        "referenced_task_id" => referenced_task_id,
        "position" => position
      })

      case Repo.insert(changeset) do
        {:ok, reference} ->
          task = Repo.preload(task, [:checklist_items, :owner, :modified_by, task_references: :referenced_task], force: true)
          broadcast_task_update(task, :updated)
          {:ok, reference}
        error -> error
      end
    else
      {:error, :unauthorized}
    end
  end

  def delete_task_reference(reference_id, user_id) do
    reference = Repo.get!(ReferenceItem, reference_id)
    |> Repo.preload(:task)

    if reference.task.owner_id == user_id || reference.task.unlocked do
      case Repo.delete(reference) do
        {:ok, _} ->
          task = get_task!(reference.task_id)
          broadcast_task_update(task, :updated)
          {:ok, reference}
        error -> error
      end
    else
      {:error, :unauthorized}
    end
  end

  defp get_next_checklist_position(task_id) do
    from(c in ChecklistItem,
      where: c.task_id == ^task_id,
      select: max(c.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      max -> max + 1
    end
  end

  defp get_next_reference_position(task_id) do
    from(r in ReferenceItem,
      where: r.task_id == ^task_id,
      select: max(r.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      max -> max + 1
    end
  end

  # Broadcasting
  defp broadcast_task_update(task, event) do
    payload = %{
      event: event,
      task: serialize_task(task)
    }

    # Broadcast to all users (since tasks are visible to all)
    Endpoint.broadcast!("tasks", "task_updated", payload)
  end

  defp serialize_task(task) do
    task
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.update(:checklist_items, [], fn items ->
      Enum.map(items, &serialize_checklist_item/1)
    end)
    |> Map.update(:task_references, [], fn refs ->
      Enum.map(refs, &serialize_reference/1)
    end)
  end

  defp serialize_checklist_item(item) do
    item
    |> Map.from_struct()
    |> Map.drop([:__meta__, :task])
  end

  defp serialize_reference(reference) do
    reference
    |> Map.from_struct()
    |> Map.drop([:__meta__, :task])
    |> Map.update(:referenced_task, nil, fn task ->
      if task do
        task
        |> Map.from_struct()
        |> Map.take([:id, :name, :state, :owner_id])
      end
    end)
  end
end
