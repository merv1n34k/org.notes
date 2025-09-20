defmodule OrgNotesWeb.PageController do
  use OrgNotesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
