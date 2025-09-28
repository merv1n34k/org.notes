defmodule OrgNotes.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OrgNotesWeb.Telemetry,
      OrgNotes.Repo,
      {Phoenix.PubSub, name: OrgNotes.PubSub},
      # Start a worker by calling: OrgNotes.Worker.start_link(arg)
      # {OrgNotes.Worker, arg},
      # Start to serve requests, typically the last entry
      OrgNotesWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OrgNotes.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OrgNotesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
