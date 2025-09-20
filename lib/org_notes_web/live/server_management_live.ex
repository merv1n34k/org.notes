defmodule OrgNotesWeb.ServerManagementLive do
  use OrgNotesWeb, :live_view
  alias OrgNotes.{Accounts, ActivityLog}

  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user!(session["user_id"])

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
        |> assign(:current_user, user)
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white shadow-sm border-b border-gray-200">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center">
              <.link navigate="/dashboard" class="mr-4">← Dashboard</.link>
              <h1 class="text-xl font-semibold">Server Management</h1>
            </div>

            <div class="text-sm text-gray-500">
              👤 <%= @current_user.name %>
            </div>
          </div>
        </div>
      </header>

      <div class="flex h-[calc(100vh-4rem)]">
        <div class="w-1/2 bg-white border-r border-gray-200 overflow-y-auto">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Users</h2>
          </div>

          <div class="divide-y divide-gray-200">
            <%= for user <- @users do %>
              <div class="px-6 py-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium text-gray-900"><%= user.name %></p>
                    <p class="text-sm text-gray-500"><%= user.email %></p>
                  </div>

                  <div class="flex items-center space-x-2">
                    <form phx-change="change_role">
                      <input type="hidden" name="user_id" value={user.id} />
                      <select
                        name="role"
                        class="text-sm border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                        disabled={user.id == @current_user.id}
                      >
                        <option value="user" selected={user.role == "user"}>User</option>
                        <option value="admin" selected={user.role == "admin"}>Admin</option>
                        <option value="super_admin" selected={user.role == "super_admin"}>Super Admin</option>
                      </select>
                    </form>

                    <%= if user.id != @current_user.id do %>
                      <button
                        phx-click="delete_user"
                        phx-value-user-id={user.id}
                        data-confirm="Are you sure you want to delete this user?"
                        class="text-red-600 hover:text-red-800"
                      >
                        🗑️
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="w-1/2 bg-gray-50 overflow-y-auto">
          <div class="px-6 py-4 bg-white border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Activity Log</h2>
          </div>

          <div class="px-6 py-2">
            <%= for entry <- @activity_log do %>
              <div class="py-2 text-sm">
                <span class="text-gray-500">
                  <%= Calendar.strftime(entry.timestamp, "%H:%M") %>
                </span>
                <span class="ml-2">
                  <%= entry.user_name %> <%= entry.action %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
