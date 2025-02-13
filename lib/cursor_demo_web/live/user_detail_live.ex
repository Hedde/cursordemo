defmodule CursorDemoWeb.UserDetailLive do
  use CursorDemoWeb, :live_view

  alias CursorDemo.{Accounts, Timeline, Repo}
  alias CursorDemoWeb.Navigation.{MobileMenuComponent, DesktopSidebarComponent, MobileTopNavComponent}
  alias CursorDemoWeb.Sidebar.{SearchComponent, WhoToFollowComponent, TrendingComponent}
  alias CursorDemoWeb.Timeline.TimelineComponent

  on_mount {CursorDemoWeb.UserAuth, :ensure_authenticated}

  def mount(%{"username" => username}, _session, socket) do
    if connected?(socket) do
      # Only subscribe to follows topic for following/follower updates
      Phoenix.PubSub.subscribe(CursorDemo.PubSub, "follows")
    end

    user = Accounts.get_user_by_username(username)
           |> Repo.preload([:followers, :following])

    if user do
      posts = Timeline.list_user_posts(user)
              |> Repo.preload([
                :user,
                :likes,
                replies: [
                  :user,
                  :likes
                ]
              ])

      socket = socket
        |> assign(
          page_title: "@#{user.username}",
          show_mobile_menu: false,
          profile_user: user,
          posts: posts,
          users_to_follow: Accounts.list_users_to_follow(socket.assigns.current_user),
          following?: Accounts.following?(socket.assigns.current_user, user),
          loading?: false,
          selected_tab: "posts", # posts, replies, likes
          processed_events: MapSet.new() # Track processed events to prevent duplicates
        )
        |> assign_new(:temporary_assigns, fn -> [processed_events: MapSet.new()] end)

      {:ok, socket}
    else
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
        <div class="xl:pr-96">
          <div class="max-w-3xl mx-auto">
            <!-- Profile header -->
            <div class="relative">
              <div class="h-32 bg-gray-200"></div>
              <div class="relative px-4 sm:px-6 lg:px-8">
                <div class="relative -mt-16 sm:-mt-20">
                  <div class="flex justify-between items-start">
                    <div class="flex-1 pr-36 sm:pr-40">
                      <div class="pt-20 sm:pt-24">
                        <h1 class="text-xl font-bold text-gray-900"><%= @profile_user.username %></h1>
                        <p class="text-sm text-gray-500">@<%= @profile_user.username %></p>

                        <%= if @profile_user.bio do %>
                          <div class="mt-4">
                            <p class="text-gray-500 whitespace-pre-wrap"><%= @profile_user.bio %></p>
                          </div>
                        <% end %>

                        <%= if @profile_user.location do %>
                          <div class="flex items-center gap-x-2 text-sm text-gray-500 mt-4">
                            <.icon name="hero-map-pin" class="w-4 h-4" />
                            <span><%= @profile_user.location %></span>
                          </div>
                        <% end %>

                        <div class="flex items-center gap-x-6 text-sm text-gray-500 mt-4">
                          <.link navigate={~p"/#{@profile_user.username}/following"} class="hover:underline">
                            <span class="font-semibold text-gray-900"><%= length(@profile_user.following) %></span> Following
                          </.link>
                          <.link navigate={~p"/#{@profile_user.username}/followers"} class="hover:underline">
                            <span class="font-semibold text-gray-900"><%= length(@profile_user.followers) %></span> Followers
                          </.link>
                        </div>
                      </div>
                    </div>

                    <div class="absolute right-0 top-0 flex flex-col items-end">
                      <img
                        class="h-32 w-32 rounded-full border-4 border-white bg-white sm:h-36 sm:w-36"
                        src={@profile_user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
                        alt=""
                      />
                      <%= if @current_user.id != @profile_user.id do %>
                        <div class="mt-4">
                          <button
                            phx-click="toggle_follow"
                            disabled={@loading?}
                            class={[
                              "rounded-full px-4 py-2 text-sm font-semibold",
                              if(@following?,
                                do: "bg-white text-gray-900 hover:bg-gray-100 ring-1 ring-inset ring-gray-300",
                                else: "bg-gray-900 text-white hover:bg-gray-800"
                              ),
                              @loading? && "opacity-50 cursor-not-allowed"
                            ]}
                          >
                            <%= if @loading? do %>
                              <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
                            <% else %>
                              <%= if @following?, do: "Volgend", else: "Volgen" %>
                            <% end %>
                          </button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <div class="border-b border-gray-200 mt-4">
                  <nav class="-mb-px flex gap-x-8">
                    <button
                      phx-click="select_tab"
                      phx-value-tab="posts"
                      class={[
                        "whitespace-nowrap py-4 px-1 text-sm font-medium border-b-2",
                        @selected_tab == "posts" && "border-gray-900 text-gray-900",
                        @selected_tab != "posts" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                      ]}
                    >
                      Posts
                    </button>
                    <button
                      phx-click="select_tab"
                      phx-value-tab="replies"
                      class={[
                        "whitespace-nowrap py-4 px-1 text-sm font-medium border-b-2",
                        @selected_tab == "replies" && "border-gray-900 text-gray-900",
                        @selected_tab != "replies" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                      ]}
                    >
                      Replies
                    </button>
                    <button
                      phx-click="select_tab"
                      phx-value-tab="likes"
                      class={[
                        "whitespace-nowrap py-4 px-1 text-sm font-medium border-b-2",
                        @selected_tab == "likes" && "border-gray-900 text-gray-900",
                        @selected_tab != "likes" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                      ]}
                    >
                      Likes
                    </button>
                  </nav>
                </div>
              </div>
            </div>

            <!-- Timeline -->
            <div class="px-4 sm:px-6 lg:px-8">
              <.live_component
                module={TimelineComponent}
                id="timeline"
                posts={@posts}
                current_user={@current_user}
                hide_post_form={true}
              />
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

  # Group all handle_event functions together
  def handle_event("toggle_follow", _, socket) do
    if socket.assigns.loading? do
      {:noreply, socket}
    else
      socket = assign(socket, :loading?, true)
      current_user = socket.assigns.current_user
      profile_user = socket.assigns.profile_user
      current_following = socket.assigns.following?

      # Do optimistic update of followers list and following state
      new_followers = if current_following do
        Enum.reject(profile_user.followers, & &1.id == current_user.id)
      else
        [%{id: current_user.id} | profile_user.followers]
      end
      profile_user = %{profile_user | followers: new_followers}

      socket = socket
        |> assign(:following?, !current_following)
        |> assign(:profile_user, profile_user)

      # Make the API call
      result = if current_following do
        Accounts.unfollow_user(current_user, profile_user)
      else
        Accounts.follow_user(current_user, profile_user)
      end

      case result do
        {:ok, _} ->
          {:noreply, assign(socket, :loading?, false)}

        :ok ->
          {:noreply, assign(socket, :loading?, false)}

        {:error, _} ->
          # On error, revert the optimistic update
          profile_user = %{profile_user | followers: profile_user.followers}
          {:noreply, socket
            |> assign(:loading?, false)
            |> assign(:following?, current_following)
            |> assign(:profile_user, profile_user)}
      end
    end
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    profile_user = socket.assigns.profile_user

    posts = case tab do
      "posts" -> Timeline.list_user_posts(profile_user)
      "replies" -> Timeline.list_user_replies(profile_user)
      "likes" -> Timeline.list_user_liked_posts(profile_user)
    end
    |> Repo.preload([
      :user,
      :likes,
      replies: [
        :user,
        :likes
      ]
    ])

    {:noreply, socket
      |> assign(:selected_tab, tab)
      |> assign(:posts, posts)}
  end

  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, show_mobile_menu: !socket.assigns.show_mobile_menu)}
  end

  # Group all handle_info functions together
  def handle_info({event_type, %{follower_id: _follower_id, followed_id: _followed_id} = data}, socket)
      when event_type in [:follow_updated, :removed_follow] do
    socket = update_follow_state(socket, event_type, data)
    {:noreply, socket}
  end

  def handle_info({:new_follow, _}, socket), do: {:noreply, socket}
  def handle_info({:new_follower, _}, socket), do: {:noreply, socket}
  def handle_info({:removed_follower, _}, socket), do: {:noreply, socket}

  # Helper function to update follow state
  defp update_follow_state(socket, event_type, %{follower_id: follower_id, followed_id: followed_id}) do
    cond do
      # If this is the profile we're viewing, update their counts
      followed_id == socket.assigns.profile_user.id ->
        # Only update if we're not the follower (since we already did optimistically)
        if follower_id != socket.assigns.current_user.id do
          profile_user = socket.assigns.profile_user

          # Check if the state matches what we're trying to do to avoid double processing
          current_is_follower = Enum.any?(profile_user.followers, & &1.id == follower_id)
          should_add = event_type == :follow_updated and not current_is_follower
          should_remove = event_type == :removed_follow and current_is_follower

          if should_add or should_remove do
            new_followers = case event_type do
              :follow_updated -> [%{id: follower_id} | profile_user.followers]
              :removed_follow -> Enum.reject(profile_user.followers, & &1.id == follower_id)
            end
            profile_user = %{profile_user | followers: new_followers}
            assign(socket, :profile_user, profile_user)
          else
            socket
          end
        else
          socket
        end

      # If this is the profile we're viewing doing the following
      follower_id == socket.assigns.profile_user.id ->
        profile_user = socket.assigns.profile_user

        # Check if the state matches what we're trying to do to avoid double processing
        current_is_following = Enum.any?(profile_user.following, & &1.id == followed_id)
        should_add = event_type == :follow_updated and not current_is_following
        should_remove = event_type == :removed_follow and current_is_following

        if should_add or should_remove do
          new_following = case event_type do
            :follow_updated -> [%{id: followed_id} | profile_user.following]
            :removed_follow -> Enum.reject(profile_user.following, & &1.id == followed_id)
          end
          profile_user = %{profile_user | following: new_following}
          assign(socket, :profile_user, profile_user)
        else
          socket
        end

      true ->
        socket
    end
  end
end
