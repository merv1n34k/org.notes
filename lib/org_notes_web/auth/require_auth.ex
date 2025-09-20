defmodule OrgNotesWeb.Auth.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller
  alias OrgNotes.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    if user_id = get_session(conn, :user_id) do
      case Accounts.get_user!(user_id) do
        nil ->
          conn
          |> configure_session(drop: true)
          |> redirect(to: "/")
          |> halt()

        user ->
          assign(conn, :current_user, user)
      end
    else
      conn
      |> redirect(to: "/")
      |> halt()
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> configure_session(drop: true)
      |> redirect(to: "/")
      |> halt()
  end
end
