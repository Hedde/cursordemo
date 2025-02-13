defmodule CursorDemo.Accounts do
  @moduledoc """
  The Accounts context handles user management and relationships.
  """

  import Ecto.Query, warn: false
  alias CursorDemo.Repo
  alias CursorDemo.Accounts.{User, Follow, UserToken}
  alias CursorDemo.Notifications

  @doc """
  Returns a list of users.
  """
  def list_users do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.all()
  end

  @doc """
  Gets a single user.
  Returns nil if the User does not exist.
  """
  def get_user(id) when is_binary(id) or is_integer(id) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get(id)
  end

  @doc """
  Gets a user by email.
  Returns nil if the User does not exist.
  """
  def get_user_by_email(email) when is_binary(email) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get_by(email: email)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if user && Bcrypt.verify_pass(password, user.password_hash), do: user
  end

  @doc """
  Gets a user by username.
  Returns nil if the User does not exist.
  """
  def get_user_by_username(username) when is_binary(username) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get_by(username: username)
  end

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a user changeset for profile editing.
  """
  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates a user's profile.
  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft deletes a user.
  """
  def delete_user(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(deleted_at: now)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Returns a list of followers for a user.
  """
  def list_followers(%User{} = user) do
    Follow
    |> where([f], f.followed_id == ^user.id)
    |> preload(:follower)
    |> Repo.all()
    |> Enum.map(& &1.follower)
  end

  @doc """
  Returns a list of users that a user is following.
  """
  def list_following(%User{} = user) do
    Follow
    |> where([f], f.follower_id == ^user.id)
    |> preload(:followed)
    |> Repo.all()
    |> Enum.map(& &1.followed)
  end

  @doc """
  Creates a follow relationship between users.
  """
  def follow_user(%User{} = follower, %User{} = followed) do
    %Follow{}
    |> Follow.changeset(%{
      follower_id: follower.id,
      followed_id: followed.id
    })
    |> Repo.insert()
    |> case do
      {:ok, follow} = result ->
        # Create notification for the followed user
        Notifications.create_notification(%{
          type: "follow",
          user_id: followed.id,
          actor_id: follower.id
        })

        # Broadcast to both the user's topic and the global follows topic
        Phoenix.PubSub.broadcast(
          CursorDemo.PubSub,
          "user:#{followed.id}",
          {:new_follower, follow}
        )

        Phoenix.PubSub.broadcast(
          CursorDemo.PubSub,
          "follows",
          {:follow_updated, %{follower_id: follower.id, followed_id: followed.id}}
        )

        result

      error ->
        error
    end
  end

  @doc """
  Removes a follow relationship between users.
  """
  def unfollow_user(%User{} = follower, %User{} = followed) do
    from(f in Follow,
      where: f.follower_id == ^follower.id and f.followed_id == ^followed.id
    )
    |> Repo.delete_all()
    |> case do
      {1, _} ->
        # Broadcast to both the user's topic and the global follows topic
        Phoenix.PubSub.broadcast(
          CursorDemo.PubSub,
          "user:#{followed.id}",
          {:removed_follower, %{follower_id: follower.id, followed_id: followed.id}}
        )

        Phoenix.PubSub.broadcast(
          CursorDemo.PubSub,
          "follows",
          {:removed_follow, %{follower_id: follower.id, followed_id: followed.id}}
        )

        :ok

      {0, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns whether a user is following another user.
  """
  def following?(%User{} = follower, %User{} = followed) do
    Repo.exists?(
      from f in Follow,
        where: f.follower_id == ^follower.id and f.followed_id == ^followed.id
    )
  end

  ## Session Management

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Email Verification

  @doc """
  Delivers the confirmation email instructions to the given user.
  """
  def deliver_user_confirmation_instructions(%User{} = user) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      encoded_token
    end
  end

  @doc """
  Confirms a user by the given token.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  @doc """
  Returns a list of users that the given user might want to follow.
  Excludes the user themselves and users they already follow.
  Limits to 3 users, ordered by most recently joined.
  """
  def list_users_to_follow(%User{} = user) do
    following_ids = list_following(user) |> Enum.map(& &1.id)
    following_ids = [user.id | following_ids]

    User
    |> where([u], is_nil(u.deleted_at))
    |> where([u], u.id not in ^following_ids)
    |> order_by([u], [desc: u.inserted_at])
    |> limit(3)
    |> Repo.all()
  end
end
