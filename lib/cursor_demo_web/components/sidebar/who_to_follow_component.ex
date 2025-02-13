defmodule CursorDemoWeb.Sidebar.WhoToFollowComponent do
  use CursorDemoWeb, :live_component

  alias CursorDemo.Accounts

  def mount(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "follows")
    end

    {:ok, assign(socket, loading_user_id: nil, users: [])}
  end

  def update(assigns, socket) do
    users = case {Map.get(assigns, :users), Map.get(assigns, :current_user)} do
      {users, current_user} when is_list(users) and not is_nil(current_user) ->
        # For each user, check if the current user is following them
        Enum.map(users, fn user ->
          following? = Accounts.following?(current_user, user)
          Map.put(user, :following?, following?)
        end)

      {users, _} when is_list(users) ->
        # No current user, mark all as not following
        Enum.map(users, &Map.put(&1, :following?, false))

      _ ->
        # No users or invalid data
        []
    end

    {:ok, assign(socket, assigns)
      |> assign(:users, users)}
  end

  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Wie te volgen</h2>
      <div class="flow-root">
        <ul role="list" class="space-y-4">
          <%= for user <- @users do %>
            <li class="flex items-center justify-between">
              <div class="flex min-w-0 items-center space-x-4">
                <div class="size-10 rounded-full bg-gray-50 overflow-hidden flex items-center justify-center">
                  <img
                    class="h-full w-full object-cover"
                    src={user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
                    alt=""
                  >
                </div>
                <div class="min-w-0 flex-auto">
                  <p class="text-sm font-medium text-gray-900 truncate"><%= user.username %></p>
                  <p class="text-sm text-gray-500 truncate"><%= user.bio %></p>
                </div>
              </div>
              <button class={[
                "ml-4",
                if(user.following?,
                  do: "rounded-full px-3 py-1.5 text-sm font-semibold bg-gray-100 text-gray-900 hover:bg-gray-200 ring-1 ring-inset ring-gray-300",
                  else: "rounded-full bg-indigo-600 px-3 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                ),
                @loading_user_id == user.id && "opacity-50 cursor-not-allowed"
              ]}
                phx-click="toggle_follow"
                phx-value-user-id={user.id}
                phx-target={@myself}
                disabled={@loading_user_id == user.id}
                type="button">
                <%= cond do %>
                  <% @loading_user_id == user.id -> %>
                    <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
                  <% user.following? -> %>
                    Volgend
                  <% true -> %>
                    Volgen
                <% end %>
              </button>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  def handle_event("toggle_follow", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.users, & &1.id == user_id)
    current_user = socket.assigns.current_user

    socket = assign(socket, loading_user_id: user_id)

    # Toggle the follow status
    result = if user.following? do
      Accounts.unfollow_user(current_user, user)
    else
      Accounts.follow_user(current_user, user)
    end

    case result do
      {:ok, _} ->
        # Update the user's following status immediately
        users = Enum.map(socket.assigns.users, fn u ->
          if u.id == user_id do
            Map.put(u, :following?, !user.following?)
          else
            u
          end
        end)

        {:noreply, socket
          |> assign(:loading_user_id, nil)
          |> assign(:users, users)}

      :ok ->
        # Update the user's following status immediately
        users = Enum.map(socket.assigns.users, fn u ->
          if u.id == user_id do
            Map.put(u, :following?, !user.following?)
          else
            u
          end
        end)

        {:noreply, socket
          |> assign(:loading_user_id, nil)
          |> assign(:users, users)}

      {:error, _} ->
        {:noreply, assign(socket, :loading_user_id, nil)}
    end
  end

  def handle_info({:follow_updated, %{follower_id: follower_id, followed_id: followed_id}}, socket) do
    # Only update the following status if needed and stop loading state
    users = Enum.map(socket.assigns.users, fn user ->
      cond do
        user.id == followed_id and follower_id == socket.assigns.current_user.id ->
          Map.put(user, :following?, true)
        user.id == followed_id and follower_id != socket.assigns.current_user.id ->
          Map.put(user, :following?, false)
        true ->
          user
      end
    end)

    {:noreply, socket
      |> assign(:users, users)
      |> assign(:loading_user_id, nil)}
  end

  def handle_info({:new_follow, data}, socket) do
    handle_info({:follow_updated, data}, socket)
  end

  def handle_info({:removed_follow, data}, socket) do
    handle_info({:follow_updated, data}, socket)
  end
end
