defmodule OrgNotesWeb.AuthController do
  use OrgNotesWeb, :controller
  alias OrgNotes.{Accounts, ActivityLog}
  plug Ueberauth

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.get_or_create_user(auth) do
      {:ok, user} ->
        # Update last login
        Accounts.update_last_login(user)

        # Log the login
        ActivityLog.log(:user_login, %{
          user_id: user.id,
          ip_address: get_ip_address(conn)
        })

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: "/dashboard")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    if user_id = get_session(conn, :user_id) do
      ActivityLog.log(:user_logout, %{
        user_id: user_id,
        ip_address: get_ip_address(conn)
      })
    end

    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
