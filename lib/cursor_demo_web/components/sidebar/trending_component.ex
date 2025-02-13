defmodule CursorDemoWeb.Sidebar.TrendingComponent do
  use CursorDemoWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Wat gebeurt er</h2>
      <div class="flow-root">
        <ul role="list" class="space-y-4">
          <%= for post <- @trending_posts do %>
            <li>
              <.link navigate={~p"/posts/#{post.id}"} class="block hover:bg-gray-50 rounded-lg -m-2 p-2">
                <div class="flex items-start space-x-3">
                  <div class="size-8 rounded-full bg-gray-50 overflow-hidden flex-shrink-0">
                    <img
                      class="h-full w-full object-cover"
                      src={post.user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
                      alt=""
                    >
                  </div>
                  <div class="min-w-0 flex-1">
                    <p class="text-sm font-medium text-gray-900">
                      <%= post.user.username %>
                    </p>
                    <p class="mt-1 text-sm text-gray-500 line-clamp-2">
                      <%= post.content %>
                    </p>
                    <div class="mt-2 flex items-center gap-x-2 text-xs text-gray-500">
                      <.icon name="hero-heart" class="h-4 w-4" />
                      <span><%= post.likes_count %></span>
                    </div>
                  </div>
                </div>
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    trending_posts = assigns.posts
      |> Enum.filter(&(!&1.parent_post_id)) # Only original posts
      |> Enum.sort_by(&(&1.likes_count), :desc)
      |> Enum.take(2)

    {:ok, assign(socket, assigns)
      |> assign(:trending_posts, trending_posts)}
  end
end
