defmodule CursorDemo.Timeline do
  @moduledoc """
  The Timeline context handles posts and interactions.
  """

  import Ecto.Query, warn: false
  alias CursorDemo.Repo
  alias CursorDemo.Timeline.{Post, Like}
  alias CursorDemo.Accounts.User
  alias CursorDemo.Notifications

  @doc """
  Returns a list of posts for the timeline.
  Optionally filtered by user_id for user-specific timelines.
  """
  def list_posts(opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    # First get all top-level posts
    top_level_posts = Post
      |> where([p], is_nil(p.deleted_at))
      |> where([p], is_nil(p.parent_post_id))
      |> maybe_filter_by_user(user_id)
      |> order_by([p], [desc: p.inserted_at])
      |> join(:left, [p], u in User, on: p.user_id == u.id)
      |> join(:left, [p], l in Like, on: l.post_id == p.id)
      |> preload([p, u, l], [
        user: u,
        likes: [user: []],
        replies: [
          :user,
          likes: [user: []],
          parent_post: [:user]
        ]
      ])
      |> Repo.all()

    # Then get all replies for these posts
    post_ids = Enum.map(top_level_posts, & &1.id)
    replies = Post
      |> where([p], is_nil(p.deleted_at))
      |> where([p], p.parent_post_id in ^post_ids)
      |> order_by([p], [asc: p.parent_post_id, asc: p.inserted_at])
      |> join(:left, [p], u in User, on: p.user_id == u.id)
      |> join(:left, [p], l in Like, on: l.post_id == p.id)
      |> preload([p, u, l], [
        user: u,
        likes: [user: []],
        parent_post: [:user]
      ])
      |> Repo.all()

    # Group replies by parent_post_id
    replies_by_parent = Enum.group_by(replies, & &1.parent_post_id)

    # Attach replies to their parent posts
    top_level_posts
    |> Enum.map(fn post ->
      Map.put(post, :replies, Map.get(replies_by_parent, post.id, []))
    end)
  end

  @doc """
  Returns a list of replies for a specific post.
  """
  def list_replies(%Post{} = post) do
    Post
    |> where([p], p.parent_post_id == ^post.id)
    |> where([p], is_nil(p.deleted_at))
    |> order_by([p], asc: p.inserted_at)
    |> preload([:user, :likes])
    |> Repo.all()
  end

  @doc """
  Gets a single post.
  """
  def get_post!(id) do
    Post
    |> where([p], is_nil(p.deleted_at))
    |> preload([
      :user,
      likes: [user: []],
      replies: [:user, likes: [user: []]]
    ])
    |> Repo.get!(id)
  end

  @doc """
  Creates a post.
  """
  def create_post(%User{} = user, attrs) do
    attrs = Map.put(attrs, :user_id, user.id)

    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, post} = result ->
        # Preload all associations before broadcasting
        post = post
          |> Repo.preload([:user, :likes, :replies])

        # Broadcast the new post
        broadcast_post(post)

        # If this is a reply, notify the parent post's author
        if parent_id = Map.get(attrs, :parent_post_id) do
          parent = get_post!(parent_id)

          unless parent.user_id == user.id do
            Notifications.create_notification(%{
              type: "mention",
              user_id: parent.user_id,
              actor_id: user.id,
              post_id: post.id
            })
          end
        end

        result

      error ->
        error
    end
  end

  @doc """
  Soft deletes a post.
  """
  def delete_post(%Post{} = post) do
    if is_nil(post.deleted_at) do
      post
      |> Post.delete_changeset()
      |> Repo.update()
      |> case do
        {:ok, post} = result ->
          # Broadcast the deletion
          Phoenix.PubSub.broadcast(
            CursorDemo.PubSub,
            "timeline:global",
            {:deleted_post, post.id}
          )

          result

        error ->
          error
      end
    else
      {:error, Ecto.Changeset.change(post)}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Creates a like on a post.
  """
  def create_like(%User{} = user, %Post{} = post) do
    # First check if the like already exists to avoid race conditions
    if liked?(user, post) do
      # If it exists, broadcast the current state and return success
      Phoenix.PubSub.broadcast(
        CursorDemo.PubSub,
        "post:#{post.id}",
        {:new_like, %{
          user_id: user.id,
          post_id: post.id,
          post_likes_count: post.likes_count
        }}
      )
      {:ok, %{user_id: user.id, post_id: post.id}}
    else
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:like, %Like{} |> Like.changeset(%{
        user_id: user.id,
        post_id: post.id
      }))
      |> Ecto.Multi.update_all(:increment_likes, from(p in Post, where: p.id == ^post.id),
        inc: [likes_count: 1]
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{like: like, increment_likes: {1, _}}} ->
          # Create notification for the post author
          unless post.user_id == user.id do
            Notifications.create_notification(%{
              type: "like",
              user_id: post.user_id,
              actor_id: user.id,
              post_id: post.id
            })
          end

          # Broadcast minimal like data instead of reloading everything
          Phoenix.PubSub.broadcast(
            CursorDemo.PubSub,
            "post:#{post.id}",
            {:new_like, %{
              id: like.id,
              user_id: user.id,
              post_id: post.id,
              post_likes_count: post.likes_count + 1
            }}
          )

          {:ok, like}

        {:error, :like, %Ecto.Changeset{errors: [user_id: {"has already been taken", _}]}, _} ->
          # Handle the race condition where the like was created between our check and insert
          # Broadcast the current state
          Phoenix.PubSub.broadcast(
            CursorDemo.PubSub,
            "post:#{post.id}",
            {:new_like, %{
              user_id: user.id,
              post_id: post.id,
              post_likes_count: post.likes_count
            }}
          )
          {:ok, %{user_id: user.id, post_id: post.id}}

        {:error, :like, changeset, _} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Removes a like from a post.
  """
  def unlike_post(%User{} = user, %Post{} = post) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:unlike, from(l in Like, where: l.user_id == ^user.id and l.post_id == ^post.id))
    |> Ecto.Multi.update_all(:decrement_likes, from(p in Post, where: p.id == ^post.id),
      inc: [likes_count: -1]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{unlike: {1, _}, decrement_likes: {1, _}}} ->
        # Broadcast minimal data instead of reloading everything
        Phoenix.PubSub.broadcast(
          CursorDemo.PubSub,
          "post:#{post.id}",
          {:removed_like, %{
            user_id: user.id,
            post_id: post.id,
            post_likes_count: post.likes_count - 1
          }}
        )
        :ok

      {:ok, %{unlike: {0, _}}} ->
        {:error, :not_found}

      {:error, _, _, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns whether a user has liked a post.
  """
  def liked?(%User{} = user, %Post{} = post) do
    Repo.exists?(
      from l in Like,
        where: l.user_id == ^user.id and l.post_id == ^post.id
    )
  end

  def list_user_posts(user) do
    Post
    |> where([p], p.user_id == ^user.id and is_nil(p.parent_post_id))
    |> order_by([p], [desc: p.inserted_at])
    |> Repo.all()
  end

  def list_user_replies(user) do
    Post
    |> where([p], p.user_id == ^user.id and not is_nil(p.parent_post_id))
    |> order_by([p], [desc: p.inserted_at])
    |> Repo.all()
  end

  def list_user_liked_posts(user) do
    Post
    |> join(:inner, [p], l in Like, on: l.post_id == p.id)
    |> where([p, l], l.user_id == ^user.id)
    |> order_by([p], [desc: p.inserted_at])
    |> distinct([p], p.id)
    |> Repo.all()
  end

  # Private functions

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id) do
    where(query, [p], p.user_id == ^user_id)
  end

  defp broadcast_post(post) do
    Phoenix.PubSub.broadcast(CursorDemo.PubSub, "timeline:global", {:new_post, post})
    Phoenix.PubSub.broadcast(CursorDemo.PubSub, "user:#{post.user_id}", {:new_post, post})
  end
end
