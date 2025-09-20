defmodule OrgNotesWeb.DashboardLive do
  use OrgNotesWeb, :live_view
  alias OrgNotes.{Tasks, Accounts}
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user!(session["user_id"])
    preferences = Accounts.get_user_preferences(user.id)

    if connected?(socket) do
      PubSub.subscribe(OrgNotes.PubSub, "user:#{user.id}")
    end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:preferences, preferences)
      |> assign(:current_organization, preferences.default_organization || "weekday")
      |> assign(:current_filters, preferences.default_filters || %{})
      |> assign(:view_stack, [])
      |> assign(:show_account_menu, false)
      |> assign(:page_title, "Dashboard")
      |> load_blocks()

    {:ok, socket}
  end

  @impl true
  def handle_event("click_block", %{"block_id" => block_id, "block_type" => block_type}, socket) do
    new_filters = case block_type do
      "weekday" -> Map.put(socket.assigns.current_filters, :day, block_id)
      "task" -> Map.put(socket.assigns.current_filters, :ids, [block_id])
      "tag" -> Map.put(socket.assigns.current_filters, :tags, [block_id])
      _ -> socket.assigns.current_filters
    end

    view_state = %{
      organization: socket.assigns.current_organization,
      filters: socket.assigns.current_filters
    }

    socket =
      socket
      |> update(:view_stack, &(&1 ++ [view_state]))
      |> assign(:current_organization, "task")
      |> assign(:current_filters, new_filters)
      |> load_blocks()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_organization", %{"organization" => organization}, socket) do
    socket =
      socket
      |> assign(:current_organization, organization)
      |> assign(:view_stack, [])
      |> load_blocks()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_filter", params, socket) do
    filters = update_filters(socket.assigns.current_filters, params)

    socket =
      socket
      |> assign(:current_filters, filters)
      |> load_blocks()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_checklist", %{"item_id" => item_id}, socket) do
    case Tasks.toggle_checklist_item(item_id, socket.assigns.user.id) do
      {:ok, _item} ->
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update item")}
    end
  end

  @impl true
  def handle_event("add_task", %{"block_id" => block_id}, socket) do
    # TODO: Implement task creation modal
    {:noreply, put_flash(socket, :info, "Add task for block: #{block_id}")}
  end

  @impl true
  def handle_event("toggle_account_menu", _, socket) do
    {:noreply, assign(socket, :show_account_menu, !socket.assigns.show_account_menu)}
  end

  @impl true
  def handle_info({:task_updated, _payload}, socket) do
    socket = load_blocks(socket)
    {:noreply, socket}
  end

  defp load_blocks(socket) do
    blocks = Tasks.list_tasks_organized(
      socket.assigns.user.id,
      socket.assigns.current_organization,
      socket.assigns.current_filters
    )

    assign(socket, :blocks, blocks)
  end

  defp update_filters(filters, %{"type" => "search", "value" => value}) do
    if value == "" do
      Map.delete(filters, :search)
    else
      Map.put(filters, :search, value)
    end
  end

  defp update_filters(filters, %{"type" => "tags", "action" => "add", "value" => tag}) do
    Map.update(filters, :tags, [tag], &(&1 ++ [tag]))
  end

  defp update_filters(filters, %{"type" => "tags", "action" => "remove", "value" => tag}) do
    case Map.get(filters, :tags, []) do
      [] -> filters
      tags ->
        new_tags = Enum.filter(tags, &(&1 != tag))
        if new_tags == [] do
          Map.delete(filters, :tags)
        else
          Map.put(filters, :tags, new_tags)
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.app_header user={@user} show_account_menu={@show_account_menu} />
      <.view_control
        current_organization={@current_organization}
        current_filters={@current_filters}
        show_back={length(@view_stack) > 0}
      />
      <.block_container blocks={@blocks} />
    </div>
    """
  end

  # Rename the function from 'header' to 'app_header':
  defp app_header(assigns) do
    ~H"""
    <header class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-10">
      <div class="px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <h1 class="text-xl font-semibold">Dashboard</h1>

          <div class="flex items-center space-x-4">
            <button class="p-2 text-gray-500 hover:text-gray-700">
              🌓
            </button>

            <div class="relative">
              <button
                phx-click="toggle_account_menu"
                class="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <span class="p-2">👤 <%= @user.name %></span>
              </button>

              <%= if @show_account_menu do %>
                <.account_dropdown user={@user} />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end


  defp account_dropdown(assigns) do
    ~H"""
    <div class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5">
      <div class="py-1">
        <div class="px-4 py-2 text-sm text-gray-700 border-b">
          <div class="font-semibold"><%= @user.name %></div>
          <div class="text-xs text-gray-500"><%= @user.email %></div>
          <%= if @user.role != "user" do %>
            <div class="text-xs text-indigo-600"><%= String.capitalize(@user.role) %></div>
          <% end %>
        </div>

        <%= if @user.role == "super_admin" do %>
          <.link href="/admin/server"
                 class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
            Manage Server
          </.link>
        <% end %>

        <.link href="/logout" method="delete"
               class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
          Logout
        </.link>
      </div>
    </div>
    """
  end

  defp view_control(assigns) do
    ~H"""
    <div class="sticky top-16 bg-white border-b border-gray-200 px-4 sm:px-6 lg:px-8 py-3 z-10">
      <div class="flex items-center space-x-4">
        <div class="flex items-center space-x-2">
          <label class="text-sm font-medium text-gray-700">Organize by:</label>
          <select
            phx-change="change_organization"
            name="organization"
            class="text-sm border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="weekday" selected={@current_organization == "weekday"}>Weekday</option>
            <option value="task" selected={@current_organization == "task"}>Task</option>
            <option value="day" selected={@current_organization == "day"}>Day</option>
            <option value="week" selected={@current_organization == "week"}>Week</option>
            <option value="month" selected={@current_organization == "month"}>Month</option>
            <option value="year" selected={@current_organization == "year"}>Year</option>
            <option value="tags" selected={@current_organization == "tags"}>Tags</option>
          </select>
        </div>

        <div class="flex-1 flex items-center space-x-2">
          <span class="text-sm font-medium text-gray-700">Filter:</span>

          <input
            type="text"
            phx-change="update_filter"
            phx-debounce="300"
            name="search"
            value={@current_filters[:search] || ""}
            placeholder="Search tasks..."
            class="flex-1 text-sm border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
          />

          <button class="p-2 text-gray-500 hover:text-gray-700">📅</button>
          <button class="p-2 text-gray-500 hover:text-gray-700">#</button>

          <%= for tag <- Map.get(@current_filters, :tags, []) do %>
            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-100 text-indigo-800">
              #<%= tag %>
              <button
                phx-click="update_filter"
                phx-value-type="tags"
                phx-value-action="remove"
                phx-value-value={tag}
                class="ml-1 text-indigo-600 hover:text-indigo-800"
              >
                ×
              </button>
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp block_container(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-6">
      <div class="flex space-x-4 overflow-x-auto">
        <%= for block <- @blocks do %>
          <.task_block block={block} />
        <% end %>
      </div>
    </div>
    """
  end

  defp task_block(assigns) do
    ~H"""
    <div class="flex-shrink-0 w-72 bg-white rounded-lg shadow">
      <div
        phx-click="click_block"
        phx-value-block-id={@block.id}
        phx-value-block-type={@block.type}
        class="px-4 py-3 border-b border-gray-200 cursor-pointer hover:bg-gray-50"
      >
        <h3 class="text-lg font-medium text-gray-900">
          <%= @block.name %>
        </h3>
        <p class="text-sm text-gray-500">
          <%= length(@block.tasks) %> <%= if length(@block.tasks) == 1, do: "task", else: "tasks" %>
        </p>
      </div>

      <div class="max-h-96 overflow-y-auto">
        <%= for task <- @block.tasks do %>
          <.task_item task={task} />
        <% end %>

        <%= if length(@block.tasks) == 0 do %>
          <div class="px-4 py-8 text-center text-gray-500">
            No tasks for <%= @block.name %>
          </div>
        <% end %>
      </div>

      <div class="px-4 py-3 border-t border-gray-200">
        <button
          phx-click="add_task"
          phx-value-block-id={@block.id}
          class="text-sm text-indigo-600 hover:text-indigo-800"
        >
          + Add Task
        </button>
      </div>
    </div>
    """
  end

  defp task_item(assigns) do
    ~H"""
    <div class="px-4 py-3 border-b border-gray-100">
      <h4 class="font-medium text-gray-900"><%= @task.name %></h4>

      <div class="flex flex-wrap gap-1 mt-1">
        <%= for tag <- @task.tags do %>
          <span class="text-xs px-2 py-0.5 bg-gray-100 text-gray-700 rounded">
            #<%= tag %>
          </span>
        <% end %>
      </div>

      <div class="mt-2 space-y-1">
        <%= for item <- Enum.filter(@task.checklist_items, &is_nil(&1.referenced_task_id)) do %>
          <.checklist_item item={item} />
        <% end %>
      </div>

      <%= if Enum.any?(@task.checklist_items, &(&1.referenced_task_id)) do %>
        <div class="mt-2 pt-2 border-t border-gray-100">
          <p class="text-xs font-medium text-gray-700 mb-1">References:</p>
          <%= for item <- Enum.filter(@task.checklist_items, &(&1.referenced_task_id)) do %>
            <div class="flex items-center text-sm text-gray-600">
              <span class="mr-2">→</span>
              <%= item.content %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp checklist_item(assigns) do
    ~H"""
    <label class="flex items-center text-sm">
      <input
        type="checkbox"
        checked={@item.completed}
        phx-click="toggle_checklist"
        phx-value-item-id={@item.id}
        class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
      />
      <span class={"ml-2 #{if @item.completed, do: "line-through text-gray-500"}"}>
        <%= @item.content %>
      </span>
    </label>
    """
  end
end
