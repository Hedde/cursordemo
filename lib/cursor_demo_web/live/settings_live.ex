defmodule CursorDemoWeb.SettingsLive do
  use CursorDemoWeb, :live_view

  alias CursorDemo.Accounts

  on_mount {CursorDemoWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_profile(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign_form(changeset)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 5_000_000, # 5MB
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Validate file upload
    {socket, user_params} =
      case socket.assigns.uploads.avatar.entries do
        [] ->
          {socket, user_params}
        [entry | _] ->
          # Validate the file type
          if entry.client_type in ~w(image/jpeg image/png) do
            {socket, user_params}
          else
            socket = put_flash(socket, :error, "Invalid file type. Please upload a JPG or PNG file.")
            {socket, Map.delete(user_params, "avatar")}
          end
      end

    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Handle avatar upload if present
    user_params = case uploaded_entries(socket, :avatar) do
      {[_entry | _], []} ->
        consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
          # Here you would typically upload to a cloud service
          # For demo purposes, we'll use a local path
          ext = Path.extname(entry.client_name)
          file_name = Path.basename(path) <> ext
          dest = Path.join("priv/static/uploads", file_name)
          File.cp!(path, dest)
          {:ok, "/uploads/" <> file_name}
        end)
        |> case do
          [url] -> Map.put(user_params, "avatar_url", url)
          _ -> user_params
        end
      _ ->
        user_params
    end

    case Accounts.update_user_profile(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings updated successfully")
         |> assign_form(Accounts.change_user_profile(user))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form, changeset: changeset)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative h-full">
      <.live_component module={CursorDemoWeb.Navigation.MobileTopNavComponent} id="mobile-top-nav" current_user={@current_user} />
      <.live_component module={CursorDemoWeb.Navigation.MobileMenuComponent} id="mobile-menu" current_user={@current_user} />
      <.live_component module={CursorDemoWeb.Navigation.DesktopSidebarComponent} id="desktop-sidebar" current_user={@current_user} />

      <main class="lg:pl-72">
        <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-8">
            <h1 class="text-2xl font-semibold leading-6 text-gray-900">Settings</h1>
            <.link navigate="/" class="text-sm font-semibold leading-6 text-gray-900 hover:text-gray-700">
              <div class="flex items-center gap-2">
                <svg class="w-5 h-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M17 10a.75.75 0 01-.75.75H5.612l4.158 3.96a.75.75 0 11-1.04 1.08l-5.5-5.25a.75.75 0 010-1.08l5.5-5.25a.75.75 0 111.04 1.08L5.612 9.25H16.25A.75.75 0 0117 10z" clip-rule="evenodd" />
                </svg>
                Back to Timeline
              </div>
            </.link>
          </div>

          <.form
            for={@form}
            id="settings-form"
            phx-change="validate"
            phx-submit="save"
            multipart={true}
            class="space-y-8"
          >
            <div>
              <label class="block text-sm font-medium leading-6 text-gray-900 mb-2">
                Profile Picture
              </label>

              <div class="flex items-center gap-x-6">
                <div class="size-16 rounded-full bg-gray-50 overflow-hidden flex items-center justify-center">
                  <img
                    class="h-full w-full object-cover"
                    src={@changeset.data.avatar_url || "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"}
                    alt=""
                  >
                </div>

                <div phx-drop-target={@uploads.avatar.ref} class="flex-1">
                  <div class="flex gap-4 items-center">
                    <.live_file_input
                      upload={@uploads.avatar}
                      class="sr-only"
                    />
                    <label for={@uploads.avatar.ref} class="cursor-pointer rounded-md bg-white px-3.5 py-2.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50">
                      Choose File
                    </label>

                    <%= if length(@uploads.avatar.entries) > 0 do %>
                      <div class="text-sm text-gray-600">
                        <%= for entry <- @uploads.avatar.entries do %>
                          <div class="flex items-center gap-2">
                            <%= entry.client_name %>
                            <div class="text-xs text-gray-500">
                              <%= entry.progress %>%
                            </div>
                            <button
                              type="button"
                              class="ml-2 text-red-600"
                              phx-click="cancel-upload"
                              phx-value-ref={entry.ref}
                              aria-label="cancel"
                            >
                              &times;
                            </button>
                          </div>
                          <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                            <div class="text-red-500 text-xs mt-1"><%= err %></div>
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>

                    <%= for err <- upload_errors(@uploads.avatar) do %>
                      <div class="text-red-500 text-xs mt-1"><%= err %></div>
                    <% end %>
                  </div>

                  <div class="mt-1 text-sm text-gray-500">
                    JPG, JPEG, or PNG. Max 5MB.
                  </div>
                </div>
              </div>
            </div>

            <div>
              <.input field={@form[:bio]} type="textarea" label="Bio" rows={4} />
              <p class="mt-2 text-sm text-gray-500">
                Write a few sentences about yourself.
              </p>
            </div>

            <div>
              <.input field={@form[:location]} type="text" label="Location" />
            </div>

            <div>
              <.input field={@form[:website]} type="url" label="Website" />
            </div>

            <div class="flex items-center justify-end gap-x-6">
              <.button type="submit" phx-disable-with="Saving...">
                Save Changes
              </.button>
            </div>
          </.form>
        </div>
      </main>
    </div>
    """
  end
end
