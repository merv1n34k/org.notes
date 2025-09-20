defmodule OrgNotes.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OrgNotes.Repo,
      {Phoenix.PubSub, name: OrgNotes.PubSub},
      OrgNotesWeb.Endpoint,
      OrgNotesWeb.Telemetry
    ]

    opts = [strategy: :one_for_one, name: OrgNotes.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OrgNotesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
