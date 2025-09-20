defmodule OrgNotes.Accounts do
  import Ecto.Query
  alias OrgNotes.{Repo, Accounts.User, Accounts.UserPreference}

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_or_create_user(auth) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname,
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
      user = %User{}
      |> User.changeset(attrs)
      |> Repo.insert!()

      %UserPreference{}
      |> UserPreference.changeset(%{user_id: user.id})
      |> Repo.insert!()

      user
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
    user
    |> User.changeset(%{last_login_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def get_user_preferences(user_id) do
    UserPreference
    |> Repo.get(user_id)
    |> case do
      nil -> %UserPreference{user_id: user_id}
      prefs -> prefs
    end
  end

  def update_user_preferences(user_id, attrs) do
    user_id
    |> get_user_preferences()
    |> UserPreference.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
