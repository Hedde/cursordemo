defmodule CursorDemoWeb.Timeline.PostComponent do
  use CursorDemoWeb, :live_component

  alias CursorDemo.Timeline

  def mount(socket) do
    {:ok, assign(socket, loading: false)}
  end

  def update(assigns, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{assigns.post.id}")
    end

    # If this is a reply, load the parent post if not already loaded
    assigns = if assigns.post.parent_post_id do
      parent_post = case assigns.post.parent_post do
        %Timeline.Post{} -> assigns.post.parent_post
        _ -> Timeline.get_post!(assigns.post.parent_post_id) |> CursorDemo.Repo.preload(:user)
      end
      Map.put(assigns, :parent_post, parent_post)
    else
      assigns
    end

    # Check if the current user has liked the post
    liked? = cond do
      # Keep optimistic state if we have it
      Map.get(socket.assigns, :optimistic_liked?) != nil ->
        socket.assigns.optimistic_liked?

      # Check likes list if preloaded
      is_list(assigns.post.likes) ->
        Enum.any?(assigns.post.likes, & &1.user_id == assigns.current_user.id)

      # Query database if likes not loaded
      true ->
        Timeline.liked?(assigns.current_user, assigns.post)
    end

    socket = socket
      |> assign(assigns)
      |> assign(:liked?, liked?)
      |> assign(:loading, false)
      |> assign(:optimistic_likes_count, assigns.post.likes_count)
      |> assign(:optimistic_liked?, liked?)

    {:ok, socket}
  end

  def handle_event("toggle_like", _params, socket) do
    if socket.assigns.loading do
      {:noreply, socket}
    else
      current_liked = socket.assigns.optimistic_liked?
      current_count = socket.assigns.optimistic_likes_count

      # Set loading state and optimistic update
      socket = socket
        |> assign(:loading, true)
        |> assign(:liked?, !current_liked)
        |> assign(:optimistic_liked?, !current_liked)
        |> assign(:optimistic_likes_count, if(current_liked, do: current_count - 1, else: current_count + 1))

      # Make the API call
      result = if current_liked do
        Timeline.unlike_post(socket.assigns.current_user, socket.assigns.post)
      else
        Timeline.create_like(socket.assigns.current_user, socket.assigns.post)
      end

      # Handle the result
      case result do
        {:ok, like} ->
          # Update the post's likes list if it's loaded
          new_socket = update_post_likes(socket, like)
          {:noreply, assign(new_socket, :loading, false)}

        :ok ->
          # Remove the like from the post's likes list if it's loaded
          new_socket = remove_post_like(socket)
          {:noreply, assign(new_socket, :loading, false)}

        {:error, _error} ->
          # On error, revert the optimistic update
          {:noreply, socket
            |> assign(:loading, false)
            |> assign(:liked?, current_liked)
            |> assign(:optimistic_liked?, current_liked)
            |> assign(:optimistic_likes_count, current_count)}
      end
    end
  end

  def handle_event("toggle_repost", _params, socket) do
    # This will be implemented later with PubSub
    {:noreply, socket}
  end

  def handle_event("toggle_reply", _params, socket) do
    # Navigate to the post's page where the reply form will be shown
    {:noreply, push_navigate(socket, to: ~p"/posts/#{socket.assigns.post.id}")}
  end

  def handle_event("share_post", _params, socket) do
    # This will be implemented later with PubSub
    {:noreply, socket}
  end

  # Helper to update the post's likes list
  defp update_post_likes(socket, like) do
    case socket.assigns.post.likes do
      likes when is_list(likes) ->
        updated_likes = [%{like | user: socket.assigns.current_user} | likes]
        assign(socket, :post, %{socket.assigns.post | likes: updated_likes})
      _ ->
        socket
    end
  end

  # Helper to remove like from the post's likes list
  defp remove_post_like(socket) do
    case socket.assigns.post.likes do
      likes when is_list(likes) ->
        updated_likes = Enum.reject(likes, & &1.user_id == socket.assigns.current_user.id)
        assign(socket, :post, %{socket.assigns.post | likes: updated_likes})
      _ ->
        socket
    end
  end

  def handle_info({:new_like, %{user_id: user_id, post_id: post_id, post_likes_count: server_count}}, socket) do
    if socket.assigns.post.id == post_id do
      is_my_like = user_id == socket.assigns.current_user.id
      new_liked? = is_my_like || socket.assigns.liked?

      new_socket = socket
        |> assign(:post, %{socket.assigns.post | likes_count: server_count})
        |> assign(:liked?, new_liked?)
        |> assign(:optimistic_liked?, new_liked?)
        |> assign(:optimistic_likes_count, server_count)
        |> assign(:loading, false)

      {:noreply, new_socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:removed_like, %{user_id: user_id, post_id: post_id, post_likes_count: server_count}}, socket) do
    if socket.assigns.post.id == post_id do
      is_my_unlike = user_id == socket.assigns.current_user.id
      new_liked? = if is_my_unlike, do: false, else: socket.assigns.liked?

      new_socket = socket
        |> assign(:post, %{socket.assigns.post | likes_count: server_count})
        |> assign(:liked?, new_liked?)
        |> assign(:optimistic_liked?, new_liked?)
        |> assign(:optimistic_likes_count, server_count)
        |> assign(:loading, false)

      {:noreply, new_socket}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "relative flex gap-x-4",
      @post.parent_post_id && "pt-4"
    ]}>
      <div class="flex-none">
        <img
          class="h-10 w-10 rounded-full bg-gray-50"
          src={@post.user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
          alt=""
        />
      </div>
      <div class="flex-1 min-w-0">
        <div class="group/post relative">
          <.link navigate={~p"/posts/#{@post.id}"} class="absolute inset-0 z-10" aria-hidden="true"></.link>
          <div class="flex flex-col">
            <div class="flex gap-x-2 text-sm leading-6">
              <div class="relative z-20 flex gap-x-1">
                <.link navigate={~p"/#{@post.user.username}"} class="font-semibold text-gray-900 hover:underline truncate">
                  <%= @post.user.username %>
                </.link>
                <span class="text-gray-500 truncate">@<%= @post.user.username %></span>
                <span class="text-gray-500 shrink-0">·</span>
                <span class="text-gray-500 shrink-0"><%= format_timestamp(@post.inserted_at) %></span>
              </div>
            </div>

            <%= if @post.parent_post_id do %>
              <div class="text-sm text-gray-500 mb-1">
                <%= case @post.parent_post do %>
                  <% %Timeline.Post{user: %{username: username}} -> %>
                    <span>Replying to <.link navigate={~p"/#{username}"} class="text-primary-600 hover:underline">@<%= username %></.link></span>
                  <% _ -> %>
                    <% parent_post = Timeline.get_post!(@post.parent_post_id) |> CursorDemo.Repo.preload(:user) %>
                    <span>Replying to <.link navigate={~p"/#{parent_post.user.username}"} class="text-primary-600 hover:underline">@<%= parent_post.user.username %></.link></span>
                <% end %>
              </div>
            <% end %>

            <div class="text-gray-900 break-words whitespace-pre-wrap"><%= @post.content %></div>

            <%= if @post.image_url do %>
              <div class="mt-2 rounded-2xl overflow-hidden">
                <img src={@post.image_url} alt="Post image" class="w-full h-auto">
              </div>
            <% end %>
          </div>
        </div>

        <div class="mt-2 mb-2 flex items-center w-full relative z-20">
          <div class="w-[100px] flex items-center gap-x-2 group">
            <button phx-click="toggle_reply" phx-target={@myself} class="p-2 -m-2 group-hover:text-primary-600">
              <.icon name="hero-chat-bubble-left" class="w-5 h-5" />
            </button>
            <span class="text-sm group-hover:text-primary-600">
              <%= case @post.replies do
                %Ecto.Association.NotLoaded{} -> 0
                replies when is_list(replies) -> length(replies)
              end %>
            </span>
          </div>
          <div class="w-[100px] flex items-center gap-x-2 group">
            <button phx-click="toggle_repost" phx-target={@myself} class="p-2 -m-2 group-hover:text-green-600">
              <.icon name="hero-arrow-path-rounded-square" class="w-5 h-5" />
            </button>
            <span class="text-sm group-hover:text-green-600"><%= @post.reposts_count %></span>
          </div>
          <div class="w-[100px] flex items-center gap-x-2 group">
            <button
              phx-click="toggle_like"
              phx-target={@myself}
              disabled={@loading}
              class={[
                "p-2 -m-2 group-hover:text-pink-600",
                @optimistic_liked? && "text-pink-600",
                @loading && "opacity-50 cursor-not-allowed"
              ]}
            >
              <.icon name={if @optimistic_liked?, do: "hero-heart-solid", else: "hero-heart"} class="w-5 h-5" />
            </button>
            <span class={[
              "text-sm group-hover:text-pink-600",
              @optimistic_liked? && "text-pink-600"
            ]}><%= @optimistic_likes_count %></span>
          </div>
          <div class="w-[100px] flex items-center gap-x-2 group">
            <button class="p-2 -m-2 group-hover:text-primary-600">
              <.icon name="hero-share" class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
