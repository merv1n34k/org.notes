defmodule OrgNotes.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias OrgNotes.{Repo, Accounts.User}

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_or_create_user(auth) do
    # Use email as fallback if name is not provided
    name = auth.info.name || auth.info.nickname || auth.info.email

    user_params = %{
      email: auth.info.email,
      name: name,
      avatar_url: auth.info.image,
      provider: to_string(auth.provider),
      provider_id: to_string(auth.uid)
    }

    case get_user_by_provider(auth.provider, auth.uid) do
      nil -> create_user(user_params)
      user -> update_user(user, user_params)
    end
  end

  def get_user_by_provider(provider, provider_id) do
    Repo.get_by(User, provider: to_string(provider), provider_id: to_string(provider_id))
  end

  def create_user(attrs \\ %{}) do
    Repo.transaction(fn ->
      # Check if this is the first user
      user_count = Repo.aggregate(User, :count)

      # If first user, make them super admin
      attrs = if user_count == 0 do
        Map.put(attrs, :role, "super_admin")
      else
        attrs
      end

      %User{}
      |> User.changeset(attrs)
      |> Repo.insert!()
    end)
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_user_role(user_id, role) when role in ["user", "admin", "super_admin"] do
    get_user!(user_id)
    |> User.changeset(%{role: role})
    |> Repo.update()
  end

  def delete_user(user_id) do
    Repo.get!(User, user_id)
    |> Repo.delete()
  end

  def list_users do
    User
    |> order_by([u], [u.name])
    |> Repo.all()
  end

  def update_last_login(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    user
    |> User.changeset(%{last_login_at: now})
    |> Repo.update()
  end
end
