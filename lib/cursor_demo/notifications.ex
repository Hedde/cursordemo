defmodule CursorDemo.Notifications do
  @moduledoc """
  The Notifications context handles user notifications.
  """

  import Ecto.Query, warn: false
  alias CursorDemo.Repo
  alias CursorDemo.Notifications.Notification
  alias CursorDemo.Accounts.User

  @doc """
  Returns a list of notifications for a user.
  """
  def list_notifications(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    include_read = Keyword.get(opts, :include_read, false)

    Notification
    |> where([n], n.user_id == ^user.id)
    |> maybe_filter_read(include_read)
    |> order_by([n], [desc: n.inserted_at])
    |> limit(^limit)
    |> preload([:actor, :post])
    |> Repo.all()
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.
  """
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} = result ->
        notification = Repo.preload(notification, [:actor, :post])
        broadcast_notification(notification)
        result

      error ->
        error
    end
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Notification.mark_as_read()
    |> Repo.update(stale_error_field: :id)
    |> case do
      {:ok, notification} = result ->
        broadcast_notification_update(notification)
        result

      error ->
        error
    end
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Notification
      |> where([n], n.user_id == ^user.id)
      |> where([n], is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now])

    if count > 0 do
      broadcast_all_read(user.id)
    end

    {:ok, count}
  end

  @doc """
  Returns the count of unread notifications for a user.
  """
  def unread_count(%User{} = user) do
    Notification
    |> where([n], n.user_id == ^user.id)
    |> where([n], is_nil(n.read_at))
    |> Repo.aggregate(:count, :id)
  end

  # Private functions

  defp maybe_filter_read(query, true), do: query
  defp maybe_filter_read(query, false) do
    where(query, [n], is_nil(n.read_at))
  end

  defp broadcast_notification(notification) do
    Phoenix.PubSub.broadcast(
      CursorDemo.PubSub,
      "notifications:#{notification.user_id}",
      {:new_notification, notification}
    )
  end

  defp broadcast_notification_update(notification) do
    Phoenix.PubSub.broadcast(
      CursorDemo.PubSub,
      "notifications:#{notification.user_id}",
      {:updated_notification, notification}
    )
  end

  defp broadcast_all_read(user_id) do
    Phoenix.PubSub.broadcast(
      CursorDemo.PubSub,
      "notifications:#{user_id}",
      :all_notifications_read
    )
  end
end
