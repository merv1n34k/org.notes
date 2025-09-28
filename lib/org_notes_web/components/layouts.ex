defmodule OrgNotesWeb.Layouts do
  @moduledoc """
  This module holds layouts for OrgNotes application.
  """
  use OrgNotesWeb, :html

  import OrgNotesWeb.NavBar
  import OrgNotesWeb.ViewControl

  embed_templates "layouts/*"

  @doc """
  App layout component for LiveView pages.
  """
  def app(assigns) do
    # Determine if ViewControl should be shown
    show_viewcontrol = show_viewcontrol?(assigns)
    assigns = assign(assigns, :show_viewcontrol, show_viewcontrol)

    ~H"""
    <div class="min-h-screen flex flex-col bg-base-100">
      <header>
        <.navbar user={assigns[:current_user]} />
        <%= if @show_viewcontrol do %>
          <.viewcontrol
            current_user={assigns[:current_user]}
            organize_by={assigns[:organize_by] || "weekday"}
            filters={assigns[:filters] || %{}}
          />
        <% end %>
      </header>

      <main class="flex-1">
        <%= @inner_content %>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # Helper function to determine if ViewControl should be shown
  defp show_viewcontrol?(assigns) do
    # Show ViewControl only on Dashboard
    # Check the module directly from socket.view
    case assigns[:socket] do
      nil -> false
      socket ->
        socket.view == OrgNotesWeb.DashboardLive
    end
  end

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" class="fixed top-20 right-4 z-50 space-y-2">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error]

  defp flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      class={[
        "min-w-[250px] max-w-sm rounded-lg px-4 py-3 shadow-lg",
        "transform transition-all duration-300 ease-out",
        "animate-slide-in-right",
        @kind == :info && "bg-white border border-gray-200",
        @kind == :error && "bg-red-50 border border-red-200"
      ]}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}
      phx-hook="AutoDismiss"
      data-duration="5000"
    >
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <%= if @kind == :info do %>
            <.icon name="hero-check-circle" class="w-5 h-5 text-green-500" />
          <% else %>
            <.icon name="hero-x-circle" class="w-5 h-5 text-red-500" />
          <% end %>
        </div>
        <div class="ml-3 flex-1">
          <p class="text-sm font-medium text-gray-900"><%= msg %></p>
        </div>
        <button
          type="button"
          class="ml-3 inline-flex text-gray-400 hover:text-gray-500"
          aria-label="Close"
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="hidden md:flex relative items-center bg-gradient-to-r from-base-200/80 to-base-300/80 backdrop-blur-sm border border-base-content/20">
      <div class="absolute w-[33.33%] h-full bg-gradient-to-r from-primary/20 to-primary/30 border border-primary/30 left-0 [[data-theme=light]_&]:left-[33.33%] [[data-theme=dark]_&]:left-[66.67%] transition-all duration-300 ease-out" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon name="hero-computer-desktop"
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon name="hero-sun"
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="relative z-10 px-3 py-2 transition-all duration-200 hover:bg-base-content/10 group"
      >
        <.icon name="hero-moon"
          class="size-4 opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-200"
        />
      </button>
    </div>
    """
  end
end
