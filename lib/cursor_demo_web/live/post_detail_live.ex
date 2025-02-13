defmodule CursorDemoWeb.PostDetailLive do
  use CursorDemoWeb, :live_view

  alias CursorDemo.Timeline
  alias CursorDemo.Repo
  alias CursorDemo.Accounts
  alias CursorDemoWeb.Navigation.{MobileMenuComponent, DesktopSidebarComponent, MobileTopNavComponent}
  alias CursorDemoWeb.Sidebar.{SearchComponent, WhoToFollowComponent, TrendingComponent}
  alias CursorDemoWeb.Timeline.CommentFormComponent
  alias CursorDemoWeb.Timeline.PostComponent

  on_mount {CursorDemoWeb.UserAuth, :ensure_authenticated}

  def mount(%{"id" => post_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "post:#{post_id}")
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "user:#{socket.assigns.current_user.id}")
    end

    post = Timeline.get_post!(post_id)
           |> Repo.preload([
             :user,
             :likes,
             parent_post: [:user],
             replies: [
               :user,
               :likes,
               :replies
             ]
           ])

    socket = socket
      |> assign(
        show_mobile_menu: false,
        post: post,
        users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user),
        trends: [], # This will be populated from the database
        page_title: "Post by @#{post.user.username}"
      )

    {:ok, socket}
  end

  def handle_info({:new_post, post}, socket) do
    # Only process if this is a reply to the current post
    if post.parent_post_id == socket.assigns.post.id do
      # Preload the reply's associations
      reply = Repo.preload(post, [
        :user,
        :likes,
        :replies,
        parent_post: [:user]
      ])

      # Get current replies and check if the reply already exists
      current_replies = socket.assigns.post.replies || []
      reply_exists? = Enum.any?(current_replies, &(&1.id == reply.id))

      if reply_exists? do
        {:noreply, socket}
      else
        # Add the new reply to the beginning of the list
        updated_post = Map.update!(socket.assigns.post, :replies, fn replies ->
          case replies do
            %Ecto.Association.NotLoaded{} -> [reply]
            existing_replies -> [reply | existing_replies]
          end
        end)

        {:noreply, assign(socket, post: updated_post)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_reply, reply}, socket) do
    # Only process if this is a reply to the current post
    if reply.parent_post_id == socket.assigns.post.id do
      # Preload the reply's associations
      reply = Repo.preload(reply, [
        :user,
        :likes,
        :replies,
        parent_post: [:user]
      ])

      # Get current replies and check if the reply already exists
      current_replies = socket.assigns.post.replies || []
      reply_exists? = Enum.any?(current_replies, &(&1.id == reply.id))

      if reply_exists? do
        {:noreply, socket}
      else
        # Add the new reply to the beginning of the list
        updated_post = Map.update!(socket.assigns.post, :replies, fn replies ->
          case replies do
            %Ecto.Association.NotLoaded{} -> [reply]
            existing_replies -> [reply | existing_replies]
          end
        end)

        {:noreply, assign(socket, post: updated_post)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_like, %{user_id: _user_id, post_id: post_id, post_likes_count: _server_count}}, socket) do
    cond do
      # If it's the main post
      post_id == socket.assigns.post.id ->
        post = Timeline.get_post!(post_id)
               |> Repo.preload([
                 :user,
                 :likes,
                 parent_post: [:user],
                 replies: [
                   :user,
                   :likes,
                   :replies
                 ]
               ])
        {:noreply, assign(socket, post: post)}

      # If it's one of the replies
      _reply = Enum.find(socket.assigns.post.replies || [], &(&1.id == post_id)) ->
        updated_reply = Timeline.get_post!(post_id)
                       |> Repo.preload([:user, :likes])

        updated_post = Map.update!(socket.assigns.post, :replies, fn replies ->
          Enum.map(replies, fn r ->
            if r.id == post_id, do: updated_reply, else: r
          end)
        end)

        {:noreply, assign(socket, post: updated_post)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:removed_like, %{user_id: _user_id, post_id: post_id, post_likes_count: _server_count}}, socket) do
    cond do
      # If it's the main post
      post_id == socket.assigns.post.id ->
        post = Timeline.get_post!(post_id)
               |> Repo.preload([
                 :user,
                 :likes,
                 parent_post: [:user],
                 replies: [
                   :user,
                   :likes,
                   :replies
                 ]
               ])
        {:noreply, assign(socket, post: post)}

      # If it's one of the replies
      _reply = Enum.find(socket.assigns.post.replies || [], &(&1.id == post_id)) ->
        updated_reply = Timeline.get_post!(post_id)
                       |> Repo.preload([:user, :likes])

        updated_post = Map.update!(socket.assigns.post, :replies, fn replies ->
          Enum.map(replies, fn r ->
            if r.id == post_id, do: updated_reply, else: r
          end)
        end)

        {:noreply, assign(socket, post: updated_post)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:new_follow, _follow}, socket) do
    # Refresh the users to follow list
    {:noreply, assign(socket, users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user))}
  end

  def handle_info({:removed_follow, _}, socket) do
    # Refresh the users to follow list
    {:noreply, assign(socket, users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user))}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full">
      <%= if @show_mobile_menu do %>
        <.live_component module={MobileMenuComponent} id="mobile-menu" current_user={@current_user} />
      <% end %>

      <.live_component module={DesktopSidebarComponent} id="desktop-sidebar" current_user={@current_user} />

      <.live_component module={MobileTopNavComponent} id="mobile-top-nav" current_user={@current_user} />

      <main class="lg:pl-72">
        <div class="xl:pr-96">
          <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
            <!-- Back button -->
            <div class="sticky top-0 z-10 bg-white/95 backdrop-blur py-2 -mx-4 px-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
              <.link
                navigate={if @post.parent_post_id, do: ~p"/posts/#{@post.parent_post_id}", else: ~p"/"}
                class="inline-flex items-center space-x-2 text-gray-500 hover:text-gray-700"
              >
                <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M17 10a.75.75 0 01-.75.75H5.612l4.158 3.96a.75.75 0 11-1.04 1.08l-5.5-5.25a.75.75 0 010-1.08l5.5-5.25a.75.75 0 111.04 1.08L5.612 9.25H16.25A.75.75 0 0117 10z" clip-rule="evenodd" />
                </svg>
                <span>
                  <%= if @post.parent_post_id do %>
                    Back to <%= @post.parent_post.user.username %>'s post
                  <% else %>
                    Back to timeline
                  <% end %>
                </span>
              </.link>
            </div>

            <!-- Original post -->
            <.live_component
              module={PostComponent}
              id={"post-#{@post.id}"}
              post={@post}
              current_user={@current_user}
              show_parent={false}
              is_last_reply={false}
            />

            <!-- Comment form -->
            <.live_component
              module={CommentFormComponent}
              id="comment-form"
              current_user={@current_user}
              parent_post_id={@post.id}
            />

            <!-- Replies -->
            <div class="divide-y divide-gray-200">
              <%= for {reply, index} <- Enum.with_index(@post.replies || []) do %>
                <div class="pt-4">
                  <.live_component
                    module={PostComponent}
                    id={"post-#{reply.id}"}
                    post={reply}
                    current_user={@current_user}
                    show_parent={false}
                    is_last_reply={index == length(@post.replies || []) - 1}
                  />
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </main>

      <aside class="fixed inset-y-0 right-0 hidden w-96 overflow-y-auto border-l border-gray-200 px-4 py-6 sm:px-6 lg:px-8 xl:block">
        <.live_component module={SearchComponent} id="search" />
        <.live_component
          module={WhoToFollowComponent}
          id="who-to-follow"
          users={@users_to_follow}
          current_user={@current_user}
        />
        <.live_component
          module={TrendingComponent}
          id="trending"
          posts={Timeline.list_posts()}
        />
      </aside>
    </div>
    """
  end

  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, show_mobile_menu: !socket.assigns.show_mobile_menu)}
  end
end
