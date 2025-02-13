defmodule CursorDemoWeb.Timeline.CommentFormComponent do
  use CursorDemoWeb, :live_component

  alias CursorDemo.Timeline

  @max_length 280

  def mount(socket) do
    {:ok, assign(socket,
      content: "",
      char_count: 0,
      loading: false,
      valid?: false,
      max_length: @max_length,
      error: nil
    )}
  end

  def update(%{current_user: nil} = assigns, socket) do
    {:ok, assign(socket, assigns)
      |> assign(error: "You must be logged in to comment")}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="border-b border-gray-200 py-8">
      <div class="flex items-start space-x-4">
        <div class="shrink-0">
          <div class="size-10 rounded-full bg-gray-50 overflow-hidden flex items-center justify-center">
            <img
              class="h-full w-full object-cover"
              src={@current_user && (@current_user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y")}
              alt=""
            >
          </div>
        </div>
        <div class="min-w-0 flex-1">
          <form phx-submit="create_comment" phx-change="validate" phx-target={@myself}>
            <div class="border-b border-gray-200 pb-px focus-within:border-b-2 focus-within:border-indigo-600 focus-within:pb-0">
              <label for="comment" class="sr-only">Add your comment</label>
              <textarea
                rows="3"
                name="content"
                id="content"
                value={@content}
                class="block w-full resize-none border-0 bg-transparent p-0 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm/6"
                placeholder={if @current_user, do: "Post your reply", else: "Sign in to reply"}
                maxlength={@max_length}
                disabled={@loading || is_nil(@current_user)}
                phx-debounce="100"
              ></textarea>
            </div>
            <%= if @error do %>
              <p class="mt-2 text-sm text-red-600"><%= @error %></p>
            <% end %>
            <div class="flex justify-end pt-2">
              <div class="flex items-center space-x-4">
                <span class={[
                  "text-sm",
                  @char_count == 0 && "text-gray-400",
                  @char_count > 0 && @char_count <= 240 && "text-gray-500",
                  @char_count > 240 && @char_count <= 270 && "text-yellow-500",
                  @char_count > 270 && "text-red-500"
                ]}>
                  <%= @max_length - @char_count %>
                </span>
                <div class="shrink-0">
                  <button
                    type="submit"
                    disabled={@loading || not @valid? || is_nil(@current_user)}
                    class={[
                      "inline-flex items-center rounded-full px-4 py-2 text-sm font-semibold text-white shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600",
                      (@loading || not @valid? || is_nil(@current_user)) && "bg-indigo-400 cursor-not-allowed",
                      !@loading && @valid? && @current_user && "bg-indigo-600 hover:bg-indigo-500"
                    ]}
                  >
                    <%= if @loading do %>
                      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    <% end %>
                    Reply
                  </button>
                </div>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"content" => content}, socket) do
    if socket.assigns.current_user do
      char_count = String.length(content)
      valid = char_count > 0 && char_count <= socket.assigns.max_length

      {:noreply, assign(socket,
        content: content,
        char_count: char_count,
        valid?: valid,
        error: nil
      )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_comment", %{"content" => content}, socket) do
    cond do
      is_nil(socket.assigns.current_user) ->
        {:noreply, assign(socket, error: "You must be logged in to comment")}

      not socket.assigns.valid? ->
        {:noreply, socket}

      true ->
        socket = assign(socket, loading: true, error: nil)

        attrs = %{
          content: content,
          parent_post_id: socket.assigns.parent_post_id
        }

        case Timeline.create_post(socket.assigns.current_user, attrs) do
          {:ok, post} ->
            # Broadcast the new post to the parent post's topic
            Phoenix.PubSub.broadcast(CursorDemo.PubSub, "post:#{socket.assigns.parent_post_id}", {:new_reply, post})

            {:noreply, assign(socket,
              content: "",
              char_count: 0,
              loading: false,
              valid?: false
            )}

          {:error, changeset} ->
            error = case changeset.errors do
              [{:content, {msg, _}}] -> msg
              _ -> "Something went wrong"
            end

            {:noreply, assign(socket,
              loading: false,
              error: error
            )}
        end
    end
  end
end
