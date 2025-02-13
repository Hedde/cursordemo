defmodule CursorDemo.TimelineFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `CursorDemo.Timeline` context.
  """

  def valid_post_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      content: "Some test content #{System.unique_integer()}",
      image_url: "http://example.com/image-#{System.unique_integer()}.jpg"
    })
  end

  def post_fixture(user, attrs \\ %{}) do
    attrs = valid_post_attributes(attrs)
    {:ok, post} = CursorDemo.Timeline.create_post(user, Map.put(attrs, :user_id, user.id))
    post
  end

  def reply_fixture(user, parent_post, attrs \\ %{}) do
    attrs =
      attrs
      |> valid_post_attributes()
      |> Map.put(:parent_post_id, parent_post.id)
      |> Map.put(:user_id, user.id)

    {:ok, post} = CursorDemo.Timeline.create_post(user, attrs)
    post
  end

  def like_fixture(user, post) do
    {:ok, like} = CursorDemo.Timeline.create_like(user, post)
    like
  end
end
