defmodule CursorDemo.TimelineTest do
  use CursorDemo.DataCase, async: true

  alias CursorDemo.Timeline
  alias CursorDemo.Timeline.{Post, Like}
  alias CursorDemo.Notifications
  alias CursorDemo.Repo

  import CursorDemo.AccountsFixtures
  import CursorDemo.TimelineFixtures

  describe "posts" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "list_posts/0 returns all top-level posts with preloaded associations", %{user: user} do
      post = post_fixture(user)
      reply = reply_fixture(user, post)

      [returned_post] = Timeline.list_posts()
      assert returned_post.id == post.id
      assert returned_post.user.id == user.id
      assert Enum.empty?(returned_post.likes)
      refute Enum.any?([returned_post], fn p -> p.id == reply.id end)
    end

    test "list_posts/1 with user_id returns user's posts", %{user: user} do
      post = post_fixture(user)
      other_user = user_fixture()
      _other_post = post_fixture(other_user)

      assert [returned_post] = Timeline.list_posts(user_id: user.id)
      assert returned_post.id == post.id
    end

    test "list_posts/0 does not return soft-deleted posts", %{user: user} do
      post = post_fixture(user)
      {:ok, _} = Timeline.delete_post(post)
      assert [] = Timeline.list_posts()
    end

    test "list_replies/1 returns all replies for a post with preloaded associations", %{user: user} do
      post = post_fixture(user)
      reply = reply_fixture(user, post)
      other_post = post_fixture(user)
      _other_reply = reply_fixture(user, other_post)

      [returned_reply] = Timeline.list_replies(post)
      assert returned_reply.id == reply.id
      assert returned_reply.user.id == user.id
      assert Enum.empty?(returned_reply.likes)
    end

    test "get_post!/1 returns the post with preloaded associations", %{user: user} do
      post = post_fixture(user)
      returned_post = Timeline.get_post!(post.id)
      assert returned_post.id == post.id
      assert returned_post.user.id == user.id
      assert Enum.empty?(returned_post.likes)
    end

    test "get_post!/1 raises for deleted post", %{user: user} do
      post = post_fixture(user)
      {:ok, _} = Timeline.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Timeline.get_post!(post.id) end
    end

    test "create_post/2 with valid data creates a post and broadcasts it", %{user: user} do
      # Subscribe to the broadcast channels
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "timeline:global")
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "user:#{user.id}")

      valid_attrs = %{content: "some content"}
      assert {:ok, %Post{} = post} = Timeline.create_post(user, valid_attrs)
      assert post.content == "some content"
      assert post.user_id == user.id

      # Assert broadcasts
      assert_receive {:new_post, broadcasted_post}
      assert broadcasted_post.id == post.id
      assert_receive {:new_post, ^broadcasted_post}
    end

    test "create_post/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Timeline.create_post(user, %{content: nil})
    end

    test "create_post/2 with parent_post_id creates a reply and notifies parent author", %{user: user} do
      other_user = user_fixture()
      parent = post_fixture(other_user)
      valid_attrs = %{content: "reply content", parent_post_id: parent.id}

      assert {:ok, %Post{} = reply} = Timeline.create_post(user, valid_attrs)
      assert reply.parent_post_id == parent.id

      # Verify notification was created
      [notification] = Notifications.list_notifications(other_user)
      assert notification.type == "mention"
      assert notification.user_id == other_user.id
      assert notification.actor_id == user.id
      assert notification.post_id == reply.id
    end

    test "create_post/2 with parent_post_id does not notify self for own post replies", %{user: user} do
      parent = post_fixture(user)
      valid_attrs = %{content: "reply content", parent_post_id: parent.id}

      assert {:ok, %Post{}} = Timeline.create_post(user, valid_attrs)
      assert [] = Notifications.list_notifications(user)
    end

    test "delete_post/1 soft deletes the post and broadcasts deletion", %{user: user} do
      post = post_fixture(user)
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "timeline:global")

      assert {:ok, %Post{}} = Timeline.delete_post(post)
      assert_receive {:deleted_post, post_id}
      assert post_id == post.id
      assert_raise Ecto.NoResultsError, fn -> Timeline.get_post!(post.id) end
    end

    test "change_post/2 returns a post changeset", %{user: user} do
      post = post_fixture(user)
      assert %Ecto.Changeset{} = Timeline.change_post(post)
      assert %Ecto.Changeset{} = Timeline.change_post(post, %{content: "updated content"})
    end

    test "create_post/2 handles database errors", %{user: user} do
      # Try to create a post with invalid content
      assert {:error, %Ecto.Changeset{}} = Timeline.create_post(user, %{content: nil})
    end

    test "create_post/2 broadcasts to global and user channels", %{user: user} do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "timeline:global")
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "user:#{user.id}")

      {:ok, post} = Timeline.create_post(user, %{content: "test post"})
      post = %{post | user: user}

      # Wait for both broadcasts
      assert_receive {:new_post, received_post}
      assert received_post.id == post.id
      assert received_post.content == post.content
      assert received_post.user_id == post.user_id

      assert_receive {:new_post, received_post}
      assert received_post.id == post.id
      assert received_post.content == post.content
      assert received_post.user_id == post.user_id
    end

    test "delete_post/1 handles database errors", %{user: user} do
      post = post_fixture(user)
      # Make the post invalid by marking it as already deleted
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      post = Ecto.Changeset.change(post, deleted_at: now)
      |> Repo.update!()

      assert {:error, %Ecto.Changeset{}} = Timeline.delete_post(post)
    end
  end

  describe "likes" do
    setup do
      user = user_fixture()
      post = post_fixture(user)
      %{user: user, post: post}
    end

    test "create_like/2 with valid data creates a like and broadcasts it", %{user: user, post: post} do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{post.id}")

      assert {:ok, %Like{} = like} = Timeline.create_like(user, post)
      assert like.user_id == user.id
      assert like.post_id == post.id

      # Assert broadcast
      assert_receive {:new_like, broadcasted_like}
      assert broadcasted_like.id == like.id
    end

    test "create_like/2 notifies post author of new like", %{post: post} do
      post = Repo.preload(post, :user)
      other_user = user_fixture()
      assert {:ok, _} = Timeline.create_like(other_user, post)

      # Verify notification
      [notification] = Notifications.list_notifications(post.user)
      assert notification.type == "like"
      assert notification.user_id == post.user_id
      assert notification.actor_id == other_user.id
      assert notification.post_id == post.id
    end

    test "create_like/2 does not notify self when liking own post", %{user: user, post: post} do
      assert {:ok, _} = Timeline.create_like(user, post)
      assert [] = Notifications.list_notifications(user)
    end

    test "create_like/2 prevents duplicate likes", %{user: user, post: post} do
      assert {:ok, %Like{}} = Timeline.create_like(user, post)
      assert {:error, changeset} = Timeline.create_like(user, post)
      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "unlike_post/2 removes a like and broadcasts it", %{user: user, post: post} do
      {:ok, _} = Timeline.create_like(user, post)
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{post.id}")

      assert :ok = Timeline.unlike_post(user, post)
      assert_receive {:removed_like, %{user_id: user_id, post_id: post_id}}
      assert user_id == user.id
      assert post_id == post.id
      refute Timeline.liked?(user, post)
    end

    test "unlike_post/2 returns error when like doesn't exist", %{user: user, post: post} do
      assert {:error, :not_found} = Timeline.unlike_post(user, post)
    end

    test "liked?/2 returns true for existing like", %{user: user, post: post} do
      {:ok, _} = Timeline.create_like(user, post)
      assert Timeline.liked?(user, post)
    end

    test "liked?/2 returns false for non-existing like", %{user: user, post: post} do
      refute Timeline.liked?(user, post)
    end

    test "create_like/2 broadcasts like event", %{user: user, post: post} do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{post.id}")

      {:ok, like} = Timeline.create_like(user, post)
      assert_receive {:new_like, ^like}
    end

    test "create_like/2 handles database errors", %{user: user, post: post} do
      # Create a like first
      {:ok, _} = Timeline.create_like(user, post)
      # Try to create it again to trigger unique constraint error
      assert {:error, %Ecto.Changeset{}} = Timeline.create_like(user, post)
    end

    test "unlike_post/2 broadcasts unlike event", %{user: user, post: post} do
      {:ok, _} = Timeline.create_like(user, post)
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{post.id}")

      :ok = Timeline.unlike_post(user, post)
      assert_receive {:removed_like, %{user_id: user_id, post_id: post_id}}
      assert user_id == user.id
      assert post_id == post.id
    end
  end

  describe "timeline fixtures" do
    test "valid_post_attributes/1 generates unique content and image_url" do
      attrs1 = valid_post_attributes()
      attrs2 = valid_post_attributes()

      assert attrs1.content != attrs2.content
      assert attrs1.image_url != attrs2.image_url
      assert String.starts_with?(attrs1.content, "Some test content")
      assert String.starts_with?(attrs1.image_url, "http://example.com/image-")
    end

    test "valid_post_attributes/1 merges provided attributes" do
      attrs = valid_post_attributes(%{content: "custom content"})
      assert Map.get(attrs, :content) == "custom content"
    end

    test "like_fixture/2 creates a like with correct associations" do
      user = user_fixture()
      post = post_fixture(user)
      like = like_fixture(user, post)

      assert like.user_id == user.id
      assert like.post_id == post.id
    end
  end
end
