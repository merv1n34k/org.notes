defmodule OrgNotesWeb.ViewControl do
  use OrgNotesWeb, :html

  attr :current_user, :any, required: true
  attr :organize_by, :string, default: "weekday"
  attr :filters, :map, default: %{}

  def viewcontrol(assigns) do
    ~H"""
    <div class="bg-base-200/50 px-4 md:px-6 lg:px-8">
      <div class="flex flex-col lg:flex-row divide-y lg:divide-y-0 lg:divide-x divide-base-300">
        <%!-- Organize Settings - Left Part --%>
        <div class="flex-1 py-3 lg:pr-6">
          <div class="flex flex-col sm:flex-row items-start sm:items-center gap-3">
            <span class="text-sm font-medium text-base-content whitespace-nowrap">
              Organize by:
            </span>
            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="weekday"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "weekday" && "bg-primary text-primary-content",
                  @organize_by != "weekday" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Weekday
              </button>
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="tasks"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "tasks" && "bg-primary text-primary-content",
                  @organize_by != "tasks" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Tasks
              </button>
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="days"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "days" && "bg-primary text-primary-content",
                  @organize_by != "days" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Days
              </button>
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="weeks"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "weeks" && "bg-primary text-primary-content",
                  @organize_by != "weeks" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Weeks
              </button>
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="months"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "months" && "bg-primary text-primary-content",
                  @organize_by != "months" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Months
              </button>
              <button
                type="button"
                phx-click="organize_by"
                phx-value-type="years"
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-lg transition-all",
                  @organize_by == "years" && "bg-primary text-primary-content",
                  @organize_by != "years" && "bg-base-300/50 text-base-content hover:bg-base-300"
                ]}
              >
                Years
              </button>
            </div>
          </div>
        </div>

        <%!-- Filter Settings - Right Part --%>
        <div class="flex-1 py-3 lg:pl-6">
          <div class="flex flex-col lg:flex-row items-start lg:items-center gap-3">
            <span class="text-sm font-medium text-base-content whitespace-nowrap">
              Filter by:
            </span>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2 w-full lg:w-auto">
              <input
                type="text"
                name="filter[name]"
                placeholder="Name..."
                phx-blur="update_filter"
                phx-value-field="name"
                value={@filters[:name]}
                class="px-3 py-1.5 text-xs bg-base-100 rounded-lg placeholder-base-content/40 focus:ring-1 focus:ring-primary focus:outline-none"
              />
              <input
                type="text"
                name="filter[tags]"
                placeholder="Tags..."
                phx-blur="update_filter"
                phx-value-field="tags"
                value={@filters[:tags]}
                class="px-3 py-1.5 text-xs bg-base-100 rounded-lg placeholder-base-content/40 focus:ring-1 focus:ring-primary focus:outline-none"
              />
              <div class="relative">
                <input
                  type="text"
                  name="filter[datetime]"
                  placeholder="Date range..."
                  phx-blur="update_filter"
                  phx-value-field="datetime"
                  value={@filters[:datetime]}
                  class="w-full px-3 py-1.5 text-xs bg-base-100 rounded-lg placeholder-base-content/40 focus:ring-1 focus:ring-primary focus:outline-none"
                  readonly
                  phx-click="show_date_picker"
                />
                <.icon name="hero-calendar" class="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40 pointer-events-none" />
              </div>
              <div class="relative">
                <input
                  type="text"
                  name="filter[user]"
                  placeholder="User..."
                  phx-blur="update_filter"
                  phx-value-field="user"
                  value={@filters[:user]}
                  class="w-full px-3 py-1.5 text-xs bg-base-100 rounded-lg placeholder-base-content/40 focus:ring-1 focus:ring-primary focus:outline-none"
                  list="users-datalist"
                />
                <.icon name="hero-user" class="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40 pointer-events-none" />
              </div>
            </div>
            <%= if any_filter_active?(@filters) do %>
              <button
                type="button"
                phx-click="clear_filters"
                class="text-xs text-base-content/60 hover:text-error transition-colors whitespace-nowrap"
              >
                <.icon name="hero-x-mark" class="w-3.5 h-3.5 inline-block mr-1" />
                Clear filters
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp any_filter_active?(filters) do
    filters
    |> Map.values()
    |> Enum.any?(&(&1 && &1 != ""))
  end
end
