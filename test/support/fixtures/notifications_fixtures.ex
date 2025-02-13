defmodule CursorDemo.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `CursorDemo.Notifications` context.
  """

  def valid_notification_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      type: "follow"
    })
  end

  def notification_fixture(attrs \\ %{}) do
    {:ok, notification} =
      attrs
      |> valid_notification_attributes()
      |> CursorDemo.Notifications.create_notification()

    notification
  end

  def like_notification_fixture(%{user: user, actor: actor, post: post}) when not is_nil(user) and not is_nil(actor) and not is_nil(post) do
    notification_fixture(%{
      type: "like",
      user_id: user.id,
      actor_id: actor.id,
      post_id: post.id
    })
  end

  def follow_notification_fixture(%{user: user, actor: actor}) when not is_nil(user) and not is_nil(actor) do
    notification_fixture(%{
      type: "follow",
      user_id: user.id,
      actor_id: actor.id
    })
  end

  def mention_notification_fixture(%{user: user, actor: actor, post: post}) when not is_nil(user) and not is_nil(actor) and not is_nil(post) do
    notification_fixture(%{
      type: "mention",
      user_id: user.id,
      actor_id: actor.id,
      post_id: post.id
    })
  end
end
