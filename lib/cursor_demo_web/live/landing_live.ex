defmodule CursorDemoWeb.LandingLive do
  use CursorDemoWeb, :live_view

  alias CursorDemoWeb.Navigation.{MobileMenuComponent, DesktopSidebarComponent, MobileTopNavComponent}
  alias CursorDemoWeb.Timeline.TimelineComponent
  alias CursorDemoWeb.Sidebar.{SearchComponent, WhoToFollowComponent, TrendingComponent}
  alias CursorDemo.Timeline
  alias CursorDemo.{Repo, Accounts}

  on_mount {CursorDemoWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "timeline:global")
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "user:#{socket.assigns.current_user.id}")
    end

    socket = socket
      |> assign(
        show_mobile_menu: false,
        posts: Timeline.list_posts(),
        users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user),
        trends: [] # This will be populated from the database
      )

    {:ok, socket}
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
          <div class="max-w-3xl mx-auto px-4 py-10 sm:px-6 lg:px-8 lg:py-6">
            <.live_component
              module={TimelineComponent}
              id="timeline"
              posts={@posts}
              current_user={@current_user}
            />
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
          posts={@posts}
        />
      </aside>
    </div>
    """
  end

  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, show_mobile_menu: !socket.assigns.show_mobile_menu)}
  end

  def handle_info({:new_post, post}, socket) do
    # Ensure all associations are loaded
    post = post
      |> Repo.preload([:user, :likes, :replies])

    # Only add the post if it's not already in the list
    updated_posts = if Enum.any?(socket.assigns.posts, & &1.id == post.id) do
      socket.assigns.posts
    else
      [post | socket.assigns.posts]
    end

    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info({:deleted_post, post_id}, socket) do
    updated_posts = Enum.reject(socket.assigns.posts, & &1.id == post_id)
    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info({:new_like, %{post_id: post_id, post_likes_count: likes_count}}, socket) do
    # Update the post's likes count without reloading
    updated_posts = Enum.map(socket.assigns.posts, fn p ->
      if p.id == post_id, do: Map.put(p, :likes_count, likes_count), else: p
    end)

    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info({:removed_like, %{post_id: post_id, post_likes_count: likes_count}}, socket) do
    # Update the post's likes count without reloading
    updated_posts = Enum.map(socket.assigns.posts, fn p ->
      if p.id == post_id, do: Map.put(p, :likes_count, likes_count), else: p
    end)

    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info({:new_reply, reply}, socket) do
    # Find the parent post and update its replies
    parent_post_id = reply.parent_post_id
    parent_post = Timeline.get_post!(parent_post_id)
                 |> Repo.preload([:user, :likes, replies: [:user, :likes]])

    # Update the post in the list
    updated_posts = Enum.map(socket.assigns.posts, fn p ->
      if p.id == parent_post_id, do: parent_post, else: p
    end)

    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info({:new_follow, _follow}, socket) do
    # Refresh the users to follow list
    {:noreply, assign(socket, users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user))}
  end

  def handle_info({:removed_follow, _}, socket) do
    # Refresh the users to follow list
    {:noreply, assign(socket, users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user))}
  end
end
