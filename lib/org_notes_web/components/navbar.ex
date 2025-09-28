defmodule OrgNotesWeb.NavBar do
  use OrgNotesWeb, :html

  def navbar(assigns) do
    ~H"""
    <nav class="bg-base-100 px-4 md:px-6 lg:px-8 relative z-50">
      <div class="flex items-center justify-between h-16">
        <%!-- Logo - Left side --%>
        <div class="flex items-center space-x-2">
          <.logo class="w-8 h-8" />
          <%= if @user do %>
            <.link navigate="/dashboard" class="text-lg font-semibold text-base-content">
              Org.Notes
            </.link>
          <% else %>
            <.link navigate="/" class="text-lg font-semibold text-base-content">
              Org.Notes
            </.link>
          <% end %>
        </div>

        <%!-- Actions - Right side --%>
        <div class="flex items-center space-x-4">
          <OrgNotesWeb.Layouts.theme_toggle />
          <.account_dropdown user={@user} />
        </div>
      </div>
    </nav>
    """
  end

  defp account_dropdown(assigns) do
    ~H"""
    <div class="relative group">
      <%= if @user do %>
        <button class="flex items-center px-3 py-2 text-sm text-base-content hover:text-base-content/80 rounded-lg hover:bg-base-200 transition-all">
          <.icon name="hero-user-circle" class="w-5 h-5 mr-2" />
          <span><%= String.slice(@user.name || @user.email, 0..20) %></span>
        </button>

        <div class="absolute right-0 mt-1 w-48 bg-base-100 rounded-lg shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
          <div class="py-1">
            <div class="px-4 py-2 border-b border-base-300">
              <p class="text-xs font-medium text-base-content"><%= @user.name %></p>
              <p class="text-xs text-base-content/60"><%= @user.email %></p>
            </div>

            <%= if @user.role == "super_admin" do %>
              <.link
                navigate="/admin/server"
                class="block px-4 py-2 text-sm text-base-content hover:bg-base-200"
              >
                Server Management
              </.link>
            <% end %>

            <.link
              href="/logout"
              method="delete"
              class="block px-4 py-2 text-sm text-error hover:bg-error/10"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 mr-2 inline-block" />
              Sign out
            </.link>
          </div>
        </div>
      <% else %>
        <.link navigate="/" class="flex items-center px-3 py-2 text-sm text-base-content hover:text-base-content/80 rounded-lg hover:bg-base-200">
          <.icon name="hero-user-circle" class="w-5 h-5 mr-2" />
          <span>Log in</span>
        </.link>
      <% end %>
    </div>
    """
  end
end
