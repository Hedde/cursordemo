defmodule CursorDemo.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @notification_types ["like", "follow", "mention"]

  schema "notifications" do
    field :type, :string
    field :read_at, :utc_datetime

    belongs_to :user, CursorDemo.Accounts.User
    belongs_to :actor, CursorDemo.Accounts.User
    belongs_to :post, CursorDemo.Timeline.Post

    timestamps()
  end

  @doc """
  Creates a notification changeset.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :read_at, :user_id, :actor_id, :post_id])
    |> validate_required([:type, :user_id, :actor_id])
    |> validate_inclusion(:type, @notification_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:post_id)
    |> validate_post_required_for_like_and_mention()
  end

  defp validate_post_required_for_like_and_mention(changeset) do
    type = get_field(changeset, :type)
    post_id = get_field(changeset, :post_id)

    case {type, post_id} do
      {type, nil} when type in ["like", "mention"] ->
        add_error(changeset, :post_id, "can't be blank for #{type} notifications")
      _ ->
        changeset
    end
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(notification) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(notification, read_at: now)
  end
end
