defmodule OrgNotesWeb.Auth.AuthHook do
  @moduledoc """
  LiveView authentication hook for on_mount callbacks.
  Sets current_user and current_scope in socket assigns.
  """

  import Phoenix.Component
  import Phoenix.LiveView
  alias OrgNotes.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:halt, redirect(socket, to: "/")}

      user_id ->
        case get_user(user_id) do
          {:ok, user} ->
            socket =
              socket
              |> assign(:current_user, user)
              |> assign(:current_scope, :authenticated)

            {:cont, socket}

          {:error, _} ->
            {:halt, redirect(socket, to: "/")}
        end
    end
  end

  defp get_user(user_id) do
    try do
      {:ok, Accounts.get_user!(user_id)}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end
end
