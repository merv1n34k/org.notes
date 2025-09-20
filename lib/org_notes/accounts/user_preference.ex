defmodule OrgNotes.Accounts.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "user_preferences" do
    field :theme, :string, default: "light"
    field :language, :string, default: "en"
    field :timezone, :string, default: "UTC"
    field :default_organization, :string, default: "weekday"
    field :default_filters, :map, default: %{}
    field :saved_view_states, {:array, :map}, default: []
    field :email_notifications, :boolean, default: true
    field :desktop_notifications, :boolean, default: false

    belongs_to :user, OrgNotes.Accounts.User, define_field: false

    timestamps()
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :theme, :language, :timezone, :default_organization,
                    :default_filters, :saved_view_states, :email_notifications,
                    :desktop_notifications])
    |> validate_required([:user_id])
    |> validate_inclusion(:theme, ["light", "dark", "auto"])
    |> validate_inclusion(:default_organization, ["weekday", "task", "day", "week", "month", "year", "tags"])
  end
end
