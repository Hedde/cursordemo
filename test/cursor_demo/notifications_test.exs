defmodule CursorDemo.NotificationsTest do
  use CursorDemo.DataCase

  alias CursorDemo.Notifications
  alias CursorDemo.Notifications.Notification

  import CursorDemo.AccountsFixtures
  import CursorDemo.TimelineFixtures
  import CursorDemo.NotificationsFixtures

  describe "notifications" do
    setup do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user)
      %{user: user, actor: actor, post: post}
    end

    test "list_notifications/2 returns all notifications for a user", ctx do
      follow_notif = follow_notification_fixture(ctx)
      like_notif = like_notification_fixture(ctx)
      mention_notif = mention_notification_fixture(ctx)

      notifications = Notifications.list_notifications(ctx.user)
      assert length(notifications) == 3
      assert Enum.map(notifications, & &1.id) |> Enum.sort() ==
             [follow_notif.id, like_notif.id, mention_notif.id] |> Enum.sort()
    end

    test "list_notifications/2 does not return other users' notifications", ctx do
      _notification = follow_notification_fixture(%{user: ctx.actor, actor: ctx.user})
      assert [] = Notifications.list_notifications(ctx.user)
    end

    test "list_notifications/2 respects the limit option", ctx do
      for _i <- 1..5 do
        follow_notification_fixture(ctx)
      end

      assert length(Notifications.list_notifications(ctx.user, limit: 3)) == 3
    end

    test "list_notifications/2 filters read notifications by default", ctx do
      notification = follow_notification_fixture(ctx)

      {:ok, _} = Notifications.mark_as_read(notification)
      assert [] = Notifications.list_notifications(ctx.user)
      assert [_] = Notifications.list_notifications(ctx.user, include_read: true)
    end

    test "get_notification!/1 returns the notification with given id", ctx do
      notification = follow_notification_fixture(ctx)
      assert Notifications.get_notification!(notification.id).id == notification.id
    end

    test "create_notification/1 creates different types of notifications", ctx do
      # Test follow notification
      assert {:ok, follow_notif} = Notifications.create_notification(%{
        type: "follow",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id
      })
      assert follow_notif.type == "follow"
      assert follow_notif.post_id == nil

      # Test like notification
      assert {:ok, like_notif} = Notifications.create_notification(%{
        type: "like",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id,
        post_id: ctx.post.id
      })
      assert like_notif.type == "like"
      assert like_notif.post_id == ctx.post.id

      # Test mention notification
      assert {:ok, mention_notif} = Notifications.create_notification(%{
        type: "mention",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id,
        post_id: ctx.post.id
      })
      assert mention_notif.type == "mention"
      assert mention_notif.post_id == ctx.post.id
    end

    test "create_notification/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notifications.create_notification(%{type: nil})
    end

    test "create_notification/1 validates notification types", ctx do
      invalid_attrs = %{
        type: "invalid",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id
      }

      assert {:error, changeset} = Notifications.create_notification(invalid_attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "mark_as_read/1 marks a notification as read", ctx do
      notification = follow_notification_fixture(ctx)
      assert {:ok, %Notification{} = updated} = Notifications.mark_as_read(notification)
      assert updated.read_at != nil
    end

    test "mark_as_read/1 broadcasts update", ctx do
      notification = follow_notification_fixture(ctx)
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "notifications:#{notification.user_id}")

      {:ok, updated} = Notifications.mark_as_read(notification)
      assert_receive {:updated_notification, ^updated}
    end

    test "mark_as_read/1 handles invalid changeset", _ctx do
      # Make the notification invalid by making it a new struct
      invalid_notification = %Notification{id: -1}
      assert {:error, %Ecto.Changeset{}} = Notifications.mark_as_read(invalid_notification)
    end

    test "mark_all_as_read/1 marks all notifications as read", ctx do
      # Create one of each type
      follow_notification_fixture(ctx)
      like_notification_fixture(ctx)
      mention_notification_fixture(ctx)

      assert {:ok, 3} = Notifications.mark_all_as_read(ctx.user)
      assert [] = Notifications.list_notifications(ctx.user)
    end

    test "mark_all_as_read/1 broadcasts when notifications exist", ctx do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "notifications:#{ctx.user.id}")

      # Create notifications
      follow_notification_fixture(ctx)
      like_notification_fixture(ctx)

      {:ok, 2} = Notifications.mark_all_as_read(ctx.user)
      assert_receive :all_notifications_read
    end

    test "mark_all_as_read/1 doesn't broadcast when no notifications exist", ctx do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "notifications:#{ctx.user.id}")

      {:ok, 0} = Notifications.mark_all_as_read(ctx.user)
      refute_receive :all_notifications_read
    end

    test "unread_count/1 returns number of unread notifications", ctx do
      # Create one of each type
      follow_notification_fixture(ctx)
      like_notification_fixture(ctx)
      mention_notification_fixture(ctx)

      notification = follow_notification_fixture(ctx)
      {:ok, _} = Notifications.mark_as_read(notification)
      assert Notifications.unread_count(ctx.user) == 3
    end

    test "validates post_id requirement for like notifications", ctx do
      attrs = %{
        type: "like",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id
      }

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert "can't be blank for like notifications" in errors_on(changeset).post_id
    end

    test "validates post_id requirement for mention notifications", ctx do
      attrs = %{
        type: "mention",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id
      }

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert "can't be blank for mention notifications" in errors_on(changeset).post_id
    end

    test "notification fixtures create valid notifications", ctx do
      # Test follow notification fixture
      follow_notif = follow_notification_fixture(ctx)
      assert follow_notif.type == "follow"
      assert follow_notif.user_id == ctx.user.id
      assert follow_notif.actor_id == ctx.actor.id
      assert follow_notif.post_id == nil

      # Test like notification fixture
      like_notif = like_notification_fixture(ctx)
      assert like_notif.type == "like"
      assert like_notif.user_id == ctx.user.id
      assert like_notif.actor_id == ctx.actor.id
      assert like_notif.post_id == ctx.post.id

      # Test mention notification fixture
      mention_notif = mention_notification_fixture(ctx)
      assert mention_notif.type == "mention"
      assert mention_notif.user_id == ctx.user.id
      assert mention_notif.actor_id == ctx.actor.id
      assert mention_notif.post_id == ctx.post.id
    end

    test "create_notification/1 broadcasts new notification", ctx do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "notifications:#{ctx.user.id}")

      {:ok, notification} = Notifications.create_notification(%{
        type: "follow",
        user_id: ctx.user.id,
        actor_id: ctx.actor.id
      })

      # Wait for the broadcast
      assert_receive {:new_notification, received_notification}
      assert received_notification.id == notification.id
      assert received_notification.type == notification.type
      assert received_notification.user_id == notification.user_id
      assert received_notification.actor_id == notification.actor_id
    end

    test "like_notification_fixture/1 validates required map keys" do
      assert_raise FunctionClauseError, fn ->
        CursorDemo.NotificationsFixtures.like_notification_fixture(%{user: nil, actor: nil, post: nil})
      end
    end

    test "follow_notification_fixture/1 validates required map keys" do
      assert_raise FunctionClauseError, fn ->
        CursorDemo.NotificationsFixtures.follow_notification_fixture(%{user: nil, actor: nil})
      end
    end

    test "mention_notification_fixture/1 validates required map keys" do
      assert_raise FunctionClauseError, fn ->
        CursorDemo.NotificationsFixtures.mention_notification_fixture(%{user: nil, actor: nil, post: nil})
      end
    end
  end

  describe "notification fixtures" do
    setup do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user)
      %{user: user, actor: actor, post: post}
    end

    test "valid_notification_attributes/1 sets default type" do
      attrs = CursorDemo.NotificationsFixtures.valid_notification_attributes()
      assert attrs.type == "follow"
    end

    test "valid_notification_attributes/1 merges provided attributes" do
      custom_attrs = %{type: "like", extra: "value"}
      attrs = CursorDemo.NotificationsFixtures.valid_notification_attributes(custom_attrs)
      assert attrs.type == "like"
      assert attrs.extra == "value"
    end

    test "notification_fixture/1 creates a notification with default attributes", %{user: user, actor: actor} do
      attrs = %{
        user_id: user.id,
        actor_id: actor.id
      }
      notification = CursorDemo.NotificationsFixtures.notification_fixture(attrs)
      assert notification.type == "follow"
      assert notification.user_id == user.id
      assert notification.actor_id == actor.id
    end

    test "notification_fixture/1 creates a notification with custom attributes", %{user: user, actor: actor, post: post} do
      attrs = %{
        type: "like",
        user_id: user.id,
        actor_id: actor.id,
        post_id: post.id
      }
      notification = CursorDemo.NotificationsFixtures.notification_fixture(attrs)
      assert notification.type == "like"
      assert notification.user_id == user.id
      assert notification.actor_id == actor.id
      assert notification.post_id == post.id
    end

    test "notification_fixture/1 handles invalid attributes" do
      # Test with completely invalid attributes
      assert_raise MatchError, fn ->
        CursorDemo.NotificationsFixtures.notification_fixture(%{type: "invalid"})
      end
    end

    test "notification_fixture/1 handles missing required attributes" do
      # Test with missing user_id and actor_id
      assert_raise MatchError, fn ->
        CursorDemo.NotificationsFixtures.notification_fixture(%{type: "follow"})
      end
    end
  end
end
