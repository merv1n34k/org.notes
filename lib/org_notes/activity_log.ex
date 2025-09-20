defmodule OrgNotes.ActivityLog do
  import Ecto.Query
  alias OrgNotes.{Repo, Logs.ActivityLog}
  alias OrgNotesWeb.Endpoint

  @actions ~w(
    user_login user_logout task_created task_updated task_deleted
    checklist_toggled checklist_item_created role_changed user_deleted task_shared
  )a

  def log(action, attrs) when action in @actions do
    %ActivityLog{}
    |> ActivityLog.changeset(%{
      action: to_string(action),
      user_id: attrs[:user_id] || attrs[:actor_id],
      task_id: attrs[:task_id],
      changes: attrs,
      ip_address: attrs[:ip_address]
    })
    |> Repo.insert()
    |> broadcast_activity()
  end

  def recent_entries(limit \\ 50) do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(&format_entry/1)
  end

  defp format_entry(entry) do
    %{
      id: entry.id,
      timestamp: entry.inserted_at,
      user_name: entry.user && entry.user.name,
      action: humanize_action(entry.action, entry.changes),
      raw: entry
    }
  end

  defp humanize_action("task_created", %{"task_name" => name}),
    do: "created task \"#{name}\""
  defp humanize_action("task_updated", _changes),
    do: "updated task"
  defp humanize_action("task_deleted", %{"task_name" => name}),
    do: "deleted task \"#{name}\""
  defp humanize_action("checklist_toggled", %{"item" => item, "completed" => true}),
    do: "checked \"#{item}\""
  defp humanize_action("checklist_toggled", %{"item" => item}),
    do: "unchecked \"#{item}\""
  defp humanize_action("checklist_item_created", %{"item" => item}),
    do: "added checklist item \"#{item}\""
  defp humanize_action("role_changed", %{"new_role" => role}),
    do: "role changed to #{role}"
  defp humanize_action("user_deleted", _),
    do: "deleted user"
  defp humanize_action("task_shared", _),
    do: "shared task"
  defp humanize_action("user_login", _),
    do: "logged in"
  defp humanize_action("user_logout", _),
    do: "logged out"
  defp humanize_action(action, _),
    do: action

  defp broadcast_activity({:ok, entry}) do
    formatted = format_entry(Repo.preload(entry, :user))
    Endpoint.broadcast!("activity_log", "new_activity", formatted)
    {:ok, entry}
  end
  defp broadcast_activity(error), do: error
end
