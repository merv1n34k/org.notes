defmodule OrgNotesWeb.Auth.RequireSuperAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns.current_user.role == "super_admin" do
      conn
    else
      conn
      |> put_flash(:error, "Unauthorized access")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
