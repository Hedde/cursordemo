defmodule CursorDemoWeb.Navigation.MobileTopNavComponent do
  use CursorDemoWeb, :live_component

  def update(%{current_user: current_user}, socket) do
    {:ok, assign(socket, current_user: current_user)}
  end

  def render(assigns) do
    ~H"""
    <div class="sticky top-0 z-40 flex items-center gap-x-6 bg-white px-4 py-4 shadow-sm sm:px-6 lg:hidden">
      <button type="button" class="-m-2.5 p-2.5 text-gray-700 lg:hidden" phx-click="toggle_mobile_menu">
        <span class="sr-only">Open sidebar</span>
        <svg class="size-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true" data-slot="icon">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
        </svg>
      </button>
      <div class="flex-1 text-sm/6 font-semibold text-gray-900">Timeline</div>
      <a href="#">
        <span class="sr-only">Your profile</span>
        <div class="size-8 rounded-full bg-gray-50 overflow-hidden flex items-center justify-center">
          <img
            class="h-full w-full object-cover"
            src={@current_user.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
            alt=""
          >
        </div>
      </a>
    </div>
    """
  end

  def handle_event("open_mobile_menu", _, socket) do
    {:noreply, socket}
  end
end
