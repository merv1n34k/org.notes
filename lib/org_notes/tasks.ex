defmodule OrgNotes.Tasks do
  import Ecto.Query
  alias OrgNotes.{Repo, Tasks.Task, Tasks.ChecklistItem, Tasks.TaskMember}
  alias OrgNotes.ActivityLog
  alias OrgNotesWeb.Endpoint

  # Task CRUD operations
  def get_task!(id) do
    Task
    |> Repo.get!(id)
    |> Repo.preload([:checklist_items, :task_members])
  end

  def create_task(attrs, user_id, _context \\ %{}) do
    attrs = Map.put(attrs, :owner_id, user_id)

    result = %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, task} ->
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
    changeset = Task.changeset(task, attrs)

    case Repo.update(changeset) do
      {:ok, task} ->
        ActivityLog.log(:task_updated, %{
          user_id: user_id,
          task_id: task.id,
          changes: changeset.changes
        })
        broadcast_task_update(task, :updated)
        {:ok, task}
      error -> error
    end
  end

  def delete_task(%Task{} = task, user_id) do
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
  end

  # Task organization and filtering
  def list_tasks_organized(user_id, organization, filters) do
    user_id
    |> base_task_query()
    |> apply_filters(filters)
    |> Repo.all()
    |> Repo.preload(:checklist_items)
    |> group_by_organization(organization)
  end

  defp base_task_query(user_id) do
    from t in Task,
      left_join: tm in TaskMember, on: tm.task_id == t.id,
      where: t.owner_id == ^user_id or tm.user_id == ^user_id,
      distinct: true
  end

  defp apply_filters(query, filters) do
    query
    |> filter_by_search(filters[:search])
    |> filter_by_date_range(filters[:date_from], filters[:date_to])
    |> filter_by_tags(filters[:tags])
    |> filter_by_day(filters[:day])
    |> filter_by_ids(filters[:ids])
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, search) do
    search_term = "%#{search}%"
    where(query, [t], ilike(t.name, ^search_term))
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, from, nil) do
    where(query, [t], t.inserted_at >= ^from)
  end
  defp filter_by_date_range(query, nil, to) do
    where(query, [t], t.inserted_at <= ^to)
  end
  defp filter_by_date_range(query, from, to) do
    where(query, [t], t.inserted_at >= ^from and t.inserted_at <= ^to)
  end

  defp filter_by_tags(query, nil), do: query
  defp filter_by_tags(query, []), do: query
  defp filter_by_tags(query, tags) do
    where(query, [t], fragment("? && ?", t.tags, ^tags))
  end

  defp filter_by_day(query, nil), do: query
  defp filter_by_day(query, day) do
    day_number = day_to_number(day)
    where(query, [t], fragment("EXTRACT(DOW FROM ?) = ?", t.inserted_at, ^day_number))
  end

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids) do
    where(query, [t], t.id in ^ids)
  end

  defp group_by_organization(tasks, "weekday") do
    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    task_groups = Enum.group_by(tasks, fn task ->
      day_num = task.inserted_at
      |> DateTime.to_date()
      |> Date.day_of_week()
      |> rem(7)

      Enum.at(days, day_num)
    end)

    Enum.map(days, fn day ->
      %{
        id: day,
        name: day,
        type: "weekday",
        tasks: Map.get(task_groups, day, [])
      }
    end)
  end

  defp group_by_organization(tasks, "task") do
    Enum.map(tasks, fn task ->
      %{
        id: task.id,
        name: task.name,
        type: "task",
        tasks: [task]
      }
    end)
  end

  defp group_by_organization(tasks, "tags") do
    tasks
    |> Enum.flat_map(fn task ->
      Enum.map(task.tags, fn tag -> {tag, task} end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {tag, tag_tasks} ->
      %{
        id: tag,
        name: "##{tag}",
        type: "tag",
        tasks: tag_tasks
      }
    end)
  end

  defp group_by_organization(tasks, "day") do
    tasks
    |> Enum.group_by(fn task ->
      Date.to_string(DateTime.to_date(task.inserted_at))
    end)
    |> Enum.map(fn {date, day_tasks} ->
      %{
        id: date,
        name: date,
        type: "day",
        tasks: day_tasks
      }
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp group_by_organization(tasks, _other) do
    # Default to task organization
    group_by_organization(tasks, "task")
  end

  defp day_to_number("Sunday"), do: 0
  defp day_to_number("Monday"), do: 1
  defp day_to_number("Tuesday"), do: 2
  defp day_to_number("Wednesday"), do: 3
  defp day_to_number("Thursday"), do: 4
  defp day_to_number("Friday"), do: 5
  defp day_to_number("Saturday"), do: 6

  # Checklist operations
  def create_checklist_item(task_id, attrs, user_id) do
    task = get_task!(task_id)
    position = get_next_position(task_id, attrs[:referenced_task_id])

    attrs = Map.put(attrs, :position, position)

    changeset = %ChecklistItem{}
    |> ChecklistItem.changeset(Map.put(attrs, :task_id, task_id))

    case Repo.insert(changeset) do
      {:ok, item} ->
        ActivityLog.log(:checklist_item_created, %{
          user_id: user_id,
          task_id: task_id,
          item: item.content
        })
        broadcast_task_update(task, :updated)
        {:ok, item}
      error -> error
    end
  end

  def toggle_checklist_item(item_id, user_id) do
    item = Repo.get!(ChecklistItem, item_id)
    |> Repo.preload(:task)

    attrs = if item.completed do
      %{completed: false, completed_at: nil, completed_by_id: nil}
    else
      %{completed: true, completed_at: DateTime.utc_now(), completed_by_id: user_id}
    end

    changeset = ChecklistItem.changeset(item, attrs)

    case Repo.update(changeset) do
      {:ok, item} ->
        ActivityLog.log(:checklist_toggled, %{
          user_id: user_id,
          task_id: item.task_id,
          item: item.content,
          completed: item.completed
        })

        # Check if task should be completed
        maybe_complete_task(item.task_id)

        broadcast_task_update(item.task, :updated)
        {:ok, item}
      error -> error
    end
  end

  defp get_next_position(task_id, nil) do
    from(c in ChecklistItem,
      where: c.task_id == ^task_id and is_nil(c.referenced_task_id),
      select: max(c.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      max -> max + 1
    end
  end

  defp get_next_position(task_id, _referenced_task_id) do
    from(c in ChecklistItem,
      where: c.task_id == ^task_id and not is_nil(c.referenced_task_id),
      select: max(c.position)
    )
    |> Repo.one()
    |> case do
      nil -> 1000
      max -> max + 1
    end
  end

  defp maybe_complete_task(task_id) do
    task = get_task!(task_id)

    all_completed = Enum.all?(task.checklist_items, fn item ->
      item.referenced_task_id != nil or item.completed
    end)

    if all_completed and task.status != "completed" do
      update_task(task, %{status: "completed", completed_at: DateTime.utc_now()}, task.owner_id)
    end
  end

  # Task member operations
  def add_task_member(task_id, user_email, added_by_id) do
    with {:ok, user} <- get_user_by_email(user_email),
         :ok <- check_not_already_member(task_id, user.id) do

      %TaskMember{}
      |> TaskMember.changeset(%{
        task_id: task_id,
        user_id: user.id,
        can_edit: false
      })
      |> Repo.insert()
      |> case do
        {:ok, member} ->
          task = get_task!(task_id)
          ActivityLog.log(:task_shared, %{
            user_id: added_by_id,
            task_id: task_id,
            shared_with_id: user.id
          })
          broadcast_task_update(task, :shared)
          {:ok, member}
        error -> error
      end
    end
  end

  defp check_not_already_member(task_id, user_id) do
    case Repo.get_by(TaskMember, task_id: task_id, user_id: user_id) do
      nil -> :ok
      _ -> {:error, :already_member}
    end
  end

  defp get_user_by_email(email) do
    case OrgNotes.Accounts.get_user_by_email(email) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  # Broadcasting
  defp broadcast_task_update(task, event) do
    payload = %{
      event: event,
      task: serialize_task(task)
    }

    # Broadcast to owner
    Endpoint.broadcast!("user:#{task.owner_id}", "task_updated", payload)

    # Broadcast to members
    task
    |> Repo.preload(:task_members)
    |> Map.get(:task_members, [])
    |> Enum.each(fn member ->
      Endpoint.broadcast!("user:#{member.user_id}", "task_updated", payload)
    end)
  end

  defp serialize_task(task) do
    task
    |> Repo.preload([:checklist_items, :task_members])
    |> Map.from_struct()
    |> Map.drop([:__meta__, :task_members])
    |> Map.update(:checklist_items, [], fn items ->
      Enum.map(items, &serialize_checklist_item/1)
    end)
  end

  defp serialize_checklist_item(item) do
    item
    |> Map.from_struct()
    |> Map.drop([:__meta__, :task])
  end
end
