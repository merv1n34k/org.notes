defmodule OrgNotesWeb.ServerManagementLive do
  use OrgNotesWeb, :live_view
  alias OrgNotes.{Accounts, ActivityLog}

  @impl true
  def mount(_params, _session, socket) do
    # current_user is now already in assigns from on_mount hook
    user = socket.assigns.current_user

    if user.role != "super_admin" do
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> push_navigate(to: "/dashboard")}
    else
      if connected?(socket) do
        :timer.send_interval(1000, self(), :refresh_activity)
        Phoenix.PubSub.subscribe(OrgNotes.PubSub, "activity_log")
      end

      socket =
        socket
        |> assign(:users, Accounts.list_users())
        |> assign(:activity_log, ActivityLog.recent_entries(50))
        |> assign(:page_title, "Server Management")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    if user_id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "Cannot change your own role")}
    else
      case Accounts.update_user_role(user_id, role) do
        {:ok, _user} ->
          ActivityLog.log(:role_changed, %{
            actor_id: socket.assigns.current_user.id,
            target_user_id: user_id,
            new_role: role
          })

          {:noreply,
           socket
           |> put_flash(:info, "Role updated successfully")
           |> assign(:users, Accounts.list_users())}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update role")}
      end
    end
  end

  @impl true
  def handle_event("delete_user", %{"user_id" => user_id}, socket) do
    if user_id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "Cannot delete yourself")}
    else
      case Accounts.delete_user(user_id) do
        {:ok, _} ->
          ActivityLog.log(:user_deleted, %{
            actor_id: socket.assigns.current_user.id,
            target_user_id: user_id
          })

          {:noreply,
           socket
           |> put_flash(:info, "User deleted successfully")
           |> assign(:users, Accounts.list_users())}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete user")}
      end
    end
  end

  @impl true
  def handle_info(:refresh_activity, socket) do
    {:noreply, assign(socket, :activity_log, ActivityLog.recent_entries(50))}
  end

  @impl true
  def handle_info({:new_activity, entry}, socket) do
    {:noreply,
     update(socket, :activity_log, fn log -> [entry | Enum.take(log, 49)] end)}
  end
end
