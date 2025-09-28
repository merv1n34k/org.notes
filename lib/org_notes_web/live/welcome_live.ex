defmodule OrgNotesWeb.WelcomeLive do
  use OrgNotesWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    case session["user_id"] do
      nil ->
        # TODO: Get total task count from database
        total_tasks = 100
        # TODO: Get actual active users
        active_users = 10

        {:ok,
         socket
         |> assign(:page_title, "Org.Notes")
         |> assign(:active_users, active_users)
         |> assign(:total_tasks, total_tasks)}
      _user_id ->
        {:ok, push_navigate(socket, to: "/dashboard")}
    end
  end
end
