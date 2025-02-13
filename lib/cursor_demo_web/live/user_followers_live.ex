defmodule CursorDemoWeb.UserFollowersLive do
  use CursorDemoWeb, :live_view

  import Ecto.Query
  alias CursorDemo.{Accounts, Repo}
  alias CursorDemoWeb.Navigation.{MobileMenuComponent, DesktopSidebarComponent, MobileTopNavComponent}
  alias CursorDemo.Accounts.User

  on_mount {CursorDemoWeb.UserAuth, :ensure_authenticated}

  def mount(%{"username" => username}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "user:#{socket.assigns.current_user.id}")
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "follows")
    end

    case Accounts.get_user_by_username(username) do
      %User{} = user ->
        # First get the IDs of users that follow this person
        follower_ids = from(f in CursorDemo.Accounts.Follow,
          where: f.followed_id == ^user.id,
          select: f.follower_id
        ) |> Repo.all()

        # Then get the actual user records
        followers = from(u in User,
          where: u.id in ^follower_ids
        )
        |> Repo.all()
        |> Enum.map(fn follower ->
          Map.put(follower, :following?, Accounts.following?(socket.assigns.current_user, follower))
        end)

        socket = socket
          |> assign(
            page_title: "@#{user.username} followers",
            show_mobile_menu: false,
            profile_user: user,
            followers: followers,
            loading_user_id: nil
          )

        {:ok, socket}

      nil ->
        {:ok, push_navigate(socket, to: "/")}
    end
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
        <div class="max-w-lg mx-auto">
          <!-- Back button -->
          <div class="sticky top-0 z-10 bg-white/95 backdrop-blur py-2 -mx-4 px-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
            <.link
              navigate={~p"/#{@profile_user.username}"}
              class="inline-flex items-center space-x-2 text-gray-500 hover:text-gray-700"
            >
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M17 10a.75.75 0 01-.75.75H5.612l4.158 3.96a.75.75 0 11-1.04 1.08l-5.5-5.25a.75.75 0 010-1.08l5.5-5.25a.75.75 0 111.04 1.08L5.612 9.25H16.25A.75.75 0 0117 10z" clip-rule="evenodd" />
              </svg>
              <span>Back to <%= @profile_user.username %>'s profile</span>
            </.link>
          </div>

          <div class="px-4 sm:px-6 lg:px-8">
            <h1 class="text-xl font-bold text-gray-900 my-4">
              <%= if @profile_user.id == @current_user.id do %>
                People following you
              <% else %>
                People following <%= @profile_user.username %>
              <% end %>
            </h1>

            <div class="flow-root">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for user <- @followers do %>
                  <li class="py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex min-w-0 items-center space-x-4">
                        <div class="size-10 rounded-full bg-gray-50 overflow-hidden flex items-center justify-center">
                          <img
                            class="h-full w-full object-cover"
                            src={user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
                            alt=""
                          >
                        </div>
                        <div class="min-w-0 flex-auto">
                          <.link navigate={~p"/#{user.username}"} class="text-sm font-medium text-gray-900 hover:underline">
                            <%= user.username %>
                          </.link>
                          <p class="text-sm text-gray-500 truncate"><%= user.bio %></p>
                        </div>
                      </div>
                      <%= if @current_user.id != user.id do %>
                        <button
                          phx-click="toggle_follow"
                          phx-value-user-id={user.id}
                          disabled={@loading_user_id == user.id}
                          class={[
                            "ml-4 rounded-full px-3 py-1.5 text-sm font-semibold",
                            if(user.following?,
                              do: "bg-white text-gray-900 hover:bg-gray-100 ring-1 ring-inset ring-gray-300",
                              else: "bg-gray-900 text-white hover:bg-gray-800"
                            ),
                            @loading_user_id == user.id && "opacity-50 cursor-not-allowed"
                          ]}
                        >
                          <%= cond do %>
                            <% @loading_user_id == user.id -> %>
                              <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
                            <% user.following? -> %>
                              Volgend
                            <% true -> %>
                              Volgen
                          <% end %>
                        </button>
                      <% end %>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def handle_event("toggle_follow", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.followers, & &1.id == user_id)

    socket = assign(socket, :loading_user_id, user_id)

    result = if user.following? do
      Accounts.unfollow_user(socket.assigns.current_user, user)
    else
      Accounts.follow_user(socket.assigns.current_user, user)
    end

    case result do
      {:ok, _} ->
        # Update the user's following status in the list
        followers = Enum.map(socket.assigns.followers, fn u ->
          if u.id == user_id do
            Map.put(u, :following?, !u.following?)
          else
            u
          end
        end)

        {:noreply, socket
          |> assign(:loading_user_id, nil)
          |> assign(:followers, followers)}

      :ok ->
        # Update the user's following status in the list
        followers = Enum.map(socket.assigns.followers, fn u ->
          if u.id == user_id do
            Map.put(u, :following?, !u.following?)
          else
            u
          end
        end)

        {:noreply, socket
          |> assign(:loading_user_id, nil)
          |> assign(:followers, followers)}

      {:error, _} ->
        {:noreply, assign(socket, :loading_user_id, nil)}
    end
  end

  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, show_mobile_menu: !socket.assigns.show_mobile_menu)}
  end

  def handle_info({:follow_updated, %{follower_id: follower_id, followed_id: followed_id}}, socket) do
    # Update the following status if needed
    followers = Enum.map(socket.assigns.followers, fn user ->
      if user.id == followed_id do
        Map.put(user, :following?, follower_id == socket.assigns.current_user.id)
      else
        user
      end
    end)

    {:noreply, assign(socket, :followers, followers)}
  end

  def handle_info({:new_follow, data}, socket) do
    handle_info({:follow_updated, data}, socket)
  end

  def handle_info({:removed_follow, data}, socket) do
    handle_info({:follow_updated, data}, socket)
  end
end
