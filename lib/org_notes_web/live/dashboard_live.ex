defmodule OrgNotesWeb.DashboardLive do
  use OrgNotesWeb, :live_view
  alias OrgNotes.Tasks

  @impl true
  def mount(_params, _session, socket) do
    # current_user is now already in assigns from on_mount hook
    if connected?(socket) do
      # Subscribe to task updates (all tasks are visible to all)
      Phoenix.PubSub.subscribe(OrgNotes.PubSub, "tasks")
    end

    tasks = Tasks.list_all_tasks()
    weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:weekday_blocks, weekday_blocks)
      |> assign(:show_task_modal, false)
      |> assign(:current_block, nil)
      |> assign(:task_form, to_form(Ecto.Changeset.change(%Tasks.Task{})))
      |> assign(:checklist_form, to_form(%{"content" => ""}))
      |> assign(:editing_task_id, nil)
      |> assign(:editing_checklist_id, nil)
      |> assign(:show_reference_modal, false)
      |> assign(:available_tasks, [])
      |> assign(:organize_by, "weekday")  # Add this
      |> assign(:filters, %{})            # Add this
      |> stream(:tasks, tasks)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_task_modal", %{"block_id" => block_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_task_modal, true)
     |> assign(:current_block, block_id)
     |> assign(:task_form, to_form(Ecto.Changeset.change(%Tasks.Task{})))}
  end

  @impl true
  def handle_event("close_task_modal", _, socket) do
    {:noreply, assign(socket, :show_task_modal, false)}
  end

  @impl true
  def handle_event("save_task", %{"task" => task_params}, socket) do
    # Parse tags from comma-separated string to array
    task_params = parse_tags(task_params)

    case Tasks.create_task(task_params, socket.assigns.current_user.id, socket.assigns.current_block) do
      {:ok, _task} ->
        tasks = Tasks.list_all_tasks()
        weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

        {:noreply,
         socket
         |> assign(:weekday_blocks, weekday_blocks)
         |> assign(:show_task_modal, false)
         |> stream(:tasks, tasks, reset: true)
         |> put_flash(:info, "Task created successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :task_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_task", %{"task" => task_params}, socket) do
    # Parse tags for validation too
    task_params = parse_tags(task_params)

    changeset =
      %Tasks.Task{}
      |> Tasks.Task.changeset(task_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :task_form, to_form(changeset))}
  end

  @impl true
  def handle_event("delete_task", %{"task_id" => task_id}, socket) do
    task = Tasks.get_task!(task_id)

    case Tasks.delete_task(task, socket.assigns.current_user.id) do
      {:ok, _task} ->
        tasks = Tasks.list_all_tasks()
        weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

        {:noreply,
         socket
         |> assign(:weekday_blocks, weekday_blocks)
         |> stream(:tasks, tasks, reset: true)
         |> put_flash(:info, "Task deleted successfully")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You can only delete your own tasks")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete task")}
    end
  end

  @impl true
  def handle_event("toggle_lock", %{"task_id" => task_id}, socket) do
    task = Tasks.get_task!(task_id)

    if task.owner_id == socket.assigns.current_user.id do
      case Tasks.toggle_task_lock(task, socket.assigns.current_user.id) do
        {:ok, _task} ->
          tasks = Tasks.list_all_tasks()
          weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

          {:noreply,
           socket
           |> assign(:weekday_blocks, weekday_blocks)
           |> stream(:tasks, tasks, reset: true)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update task lock")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the task owner can change lock status")}
    end
  end

  @impl true
  def handle_event("toggle_checklist", %{"item_id" => item_id}, socket) do
    case Tasks.toggle_checklist_item(item_id, socket.assigns.current_user.id) do
      {:ok, item} ->
        # Check if we should auto-complete the task
        task = Tasks.get_task!(item.task_id)
        Tasks.maybe_auto_complete_task(task, socket.assigns.current_user.id)

        tasks = Tasks.list_all_tasks()
        weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

        socket =
          socket
          |> assign(:weekday_blocks, weekday_blocks)
          |> stream(:tasks, tasks, reset: true)

        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update item")}
    end
  end

  @impl true
  def handle_event("add_checklist_item", %{"task_id" => task_id}, socket) do
    {:noreply,
     socket
     |> assign(:editing_task_id, task_id)
     |> assign(:editing_checklist_id, nil)
     |> assign(:checklist_form, to_form(%{"content" => ""}))}
  end

  @impl true
  def handle_event("edit_checklist_item", %{"item_id" => item_id}, socket) do
    item = Tasks.get_checklist_item!(item_id)

    {:noreply,
     socket
     |> assign(:editing_task_id, item.task_id)
     |> assign(:editing_checklist_id, item.id)
     |> assign(:checklist_form, to_form(%{"content" => item.content}))}
  end

  @impl true
  def handle_event("save_checklist_item", %{"checklist" => %{"content" => content}}, socket) do
    if socket.assigns.editing_checklist_id do
      # Update existing item
      case Tasks.update_checklist_item(socket.assigns.editing_checklist_id, %{"content" => content}, socket.assigns.current_user.id) do
        {:ok, _item} ->
          tasks = Tasks.list_all_tasks()
          weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

          {:noreply,
           socket
           |> assign(:weekday_blocks, weekday_blocks)
           |> assign(:editing_task_id, nil)
           |> assign(:editing_checklist_id, nil)
           |> stream(:tasks, tasks, reset: true)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update checklist item")}
      end
    else
      # Create new item
      case Tasks.create_checklist_item(socket.assigns.editing_task_id, %{"content" => content}, socket.assigns.current_user.id) do
        {:ok, _item} ->
          tasks = Tasks.list_all_tasks()
          weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

          {:noreply,
           socket
           |> assign(:weekday_blocks, weekday_blocks)
           |> assign(:editing_task_id, nil)
           |> assign(:editing_checklist_id, nil)
           |> stream(:tasks, tasks, reset: true)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not add checklist item")}
      end
    end
  end

  @impl true
  def handle_event("delete_checklist_item", _, socket) do
    if socket.assigns.editing_checklist_id do
      case Tasks.delete_checklist_item(socket.assigns.editing_checklist_id, socket.assigns.current_user.id) do
        {:ok, _item} ->
          tasks = Tasks.list_all_tasks()
          weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

          {:noreply,
           socket
           |> assign(:weekday_blocks, weekday_blocks)
           |> assign(:editing_task_id, nil)
           |> assign(:editing_checklist_id, nil)
           |> stream(:tasks, tasks, reset: true)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete checklist item")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_checklist", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_task_id, nil)
     |> assign(:editing_checklist_id, nil)}
  end

  @impl true
  def handle_event("open_reference_modal", %{"task_id" => task_id}, socket) do
    available_tasks = Tasks.list_available_tasks(task_id)

    {:noreply,
     socket
     |> assign(:show_reference_modal, true)
     |> assign(:editing_task_id, task_id)
     |> assign(:available_tasks, available_tasks)}
  end

  @impl true
  def handle_event("close_reference_modal", _, socket) do
    {:noreply, assign(socket, :show_reference_modal, false)}
  end

  @impl true
  def handle_event("add_reference", %{"referenced_task_id" => referenced_task_id}, socket) do
    case Tasks.create_task_reference(socket.assigns.editing_task_id, referenced_task_id, socket.assigns.current_user.id) do
      {:ok, _reference} ->
        tasks = Tasks.list_all_tasks()
        weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

        {:noreply,
         socket
         |> assign(:weekday_blocks, weekday_blocks)
         |> assign(:show_reference_modal, false)
         |> stream(:tasks, tasks, reset: true)
         |> put_flash(:info, "Reference added successfully")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You cannot edit this task")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add reference")}
    end
  end

  @impl true
  def handle_event("organize_by", %{"type" => type}, socket) do
    # TODO: Implement organization logic
    {:noreply,
     socket
     |> assign(:organize_by, type)
     |> put_flash(:info, "Organization changed to #{type}")}
  end

  @impl true
  def handle_event("update_filter", %{"field" => field, "value" => value}, socket) do
    # TODO: Implement filtering logic
    filters = Map.put(socket.assigns.filters, String.to_atom(field), value)
    {:noreply,
     socket
     |> assign(:filters, filters)
     |> put_flash(:info, "Filter updated")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    # TODO: Implement clear filters logic
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> put_flash(:info, "Filters cleared")}
  end

  @impl true
  def handle_event("show_date_picker", _, socket) do
    # TODO: Implement date picker modal
    {:noreply, put_flash(socket, :info, "Date picker coming soon")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "task_updated", payload: _payload}, socket) do
    tasks = Tasks.list_all_tasks()
    weekday_blocks = Tasks.group_tasks_by_weekday(tasks)

    socket =
      socket
      |> assign(:weekday_blocks, weekday_blocks)
      |> stream(:tasks, tasks, reset: true)

    {:noreply, socket}
  end

  # Catch-all handle_info for any other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Helper functions
  def state_badge_class("active"), do: "bg-success/20 text-success font-medium"
  def state_badge_class("completed"), do: "bg-info/20 text-info"
  def state_badge_class("archived"), do: "bg-base-300 text-base-content/50"
  def state_badge_class(_), do: "bg-base-300 text-base-content/60"

  def format_time(datetime) do
    # Use %I for 12-hour format instead of %l
    Calendar.strftime(datetime, "%b %d, %I:%M %p") |> String.trim()
  end

  def can_edit?(task, user) do
    task.owner_id == user.id || task.unlocked
  end

  def task_completion_state(task) do
    case task.checklist_items do
      [] -> "active"
      items ->
        all_completed = Enum.all?(items, fn item -> item.state == "completed" end)
        if all_completed, do: "completed", else: "active"
    end
  end

  # Parse tags from comma-separated string to array
  defp parse_tags(params) do
    case Map.get(params, "tags") do
      nil ->
        params
      "" ->
        Map.put(params, "tags", [])
      tags_string when is_binary(tags_string) ->
        tags = tags_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

        Map.put(params, "tags", tags)
      tags when is_list(tags) ->
        params
    end
  end
end
