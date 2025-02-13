defmodule CursorDemoWeb.Timeline.TimelineComponent do
  use CursorDemoWeb, :live_component

  alias CursorDemoWeb.Timeline.{PostFormComponent, PostComponent}

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flow-root">
      <%= unless @hide_post_form do %>
        <.live_component
          module={PostFormComponent}
          id="post-form"
          current_user={@current_user}
        />
      <% end %>

      <ul role="list">
        <%= for post <- @posts do %>
          <%= if !post.parent_post_id do %>
            <li class="border-b border-gray-200 py-6">
              <div class="relative">
                <%= if post.replies && length(post.replies) > 0 do %>
                  <span class="absolute left-5 top-10 w-0.5 bg-gray-200"
                    style={"height: #{16 + (length(post.replies) * 40) + ((length(post.replies) - 1) * 16)}px"}
                    aria-hidden="true">
                  </span>
                <% end %>
                <div class="relative flex min-w-0 w-full">
                  <.live_component
                    module={PostComponent}
                    id={"post-#{post.id}"}
                    post={post}
                    current_user={@current_user}
                    class="flex-1 min-w-0 w-full"
                  />
                </div>

                <%= if post.replies && length(post.replies) > 0 do %>
                  <div class="space-y-4 pt-4">
                    <%= for reply <- post.replies do %>
                      <div class="relative flex min-w-0 w-full">
                        <.live_component
                          module={PostComponent}
                          id={"post-#{reply.id}"}
                          post={reply}
                          current_user={@current_user}
                          parent_post={post}
                          class="flex-1 min-w-0 w-full"
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end

  def update(assigns, socket) do
    assigns = assigns
      |> Map.put_new(:hide_post_form, false)

    {:ok, assign(socket, assigns)}
  end
end
