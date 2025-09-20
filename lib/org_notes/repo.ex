defmodule OrgNotes.Repo do
  use Ecto.Repo,
    otp_app: :org_notes,
    adapter: Ecto.Adapters.Postgres
end
