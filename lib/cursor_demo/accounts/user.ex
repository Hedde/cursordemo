defmodule CursorDemo.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias CursorDemo.Timeline.{Post, Like}
  alias CursorDemo.Notifications.Notification
  alias CursorDemo.Accounts.Follow

  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true  # Virtual field for password
    field :password_hash, :string
    field :avatar_url, :string
    field :bio, :string
    field :location, :string
    field :website, :string
    field :deleted_at, :utc_datetime

    # Auth fields
    field :confirmed_at, :naive_datetime
    field :confirmation_token, :string
    field :confirmation_sent_at, :naive_datetime
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :last_sign_in_ip, :string

    # Relationships
    has_many :posts, Post
    has_many :likes, Like
    has_many :notifications, Notification

    # Follow relationships
    has_many :following, Follow, foreign_key: :follower_id
    has_many :followers, Follow, foreign_key: :followed_id

    timestamps()
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :password])
    |> validate_required([:email, :username, :password])
    |> validate_email()
    |> validate_username()
    |> validate_password()
    |> maybe_generate_confirmation_token()
  end

  @doc """
  A user changeset for updating the profile.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:bio, :location, :website, :avatar_url])
    |> validate_length(:bio, max: 160)
    |> validate_length(:location, max: 100)
    |> validate_length(:website, max: 100)
  end

  @doc """
  Verifies a user's email.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  A changeset for changing the user's password.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
  end

  @doc """
  A changeset for changing the password through reset.
  """
  def reset_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> change(%{
      reset_password_token: nil,
      reset_password_sent_at: nil
    })
  end

  @doc """
  Generates a password reset token.
  """
  def reset_password_token_changeset(user) do
    token = generate_token()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    change(user, %{
      reset_password_token: token,
      reset_password_sent_at: now
    })
  end

  @doc """
  Updates the user's last sign in information.
  """
  def sign_in_changeset(user, ip) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, last_sign_in_at: now, last_sign_in_ip: ip)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@ictu\.nl$/, message: "must be an @ictu.nl email address")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, CursorDemo.Repo)
    |> unique_constraint(:email)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "only letters, numbers, and underscores allowed")
    |> validate_length(:username, min: 3, max: 20)
    |> unsafe_validate_unique(:username, CursorDemo.Repo)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!@#$%^&*(),.?":{}|<>]/, message: "at least one symbol")
    |> prepare_changes(&hash_password/1)
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    changeset
    |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp maybe_generate_confirmation_token(changeset) do
    if Mix.env() in [:dev, :test] do
      # Auto-confirm in dev/test
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      change(changeset, confirmed_at: now)
    else
      # Generate confirmation token for production
      token = generate_token()
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      change(changeset, %{
        confirmation_token: token,
        confirmation_sent_at: now
      })
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end
