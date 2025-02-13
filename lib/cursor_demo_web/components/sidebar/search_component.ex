defmodule CursorDemoWeb.Sidebar.SearchComponent do
  use CursorDemoWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Zoeken</h2>
      <div class="relative mt-2 rounded-md shadow-sm">
        <input type="text"
               class="block w-full rounded-md border-0 py-1.5 pl-4 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
               placeholder="Zoeken..."
               phx-keyup="search"
               phx-target={@myself}
               value={@query}>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, query: "")}
  end

  def handle_event("search", %{"value" => query}, socket) do
    # This will be implemented later with PubSub
    {:noreply, assign(socket, query: query)}
  end
end
