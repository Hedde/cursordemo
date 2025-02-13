defmodule CursorDemoWeb.Timeline.PostFormComponentTest do
  use CursorDemoWeb.LiveCase, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest
  import CursorDemo.AccountsFixtures

  alias CursorDemoWeb.Timeline.PostFormComponent

  @endpoint CursorDemoWeb.Endpoint

  defmodule TestLive do
    use CursorDemoWeb, :live_view

    def mount(_params, session, socket) do
      {:ok, assign(socket, current_user: session["current_user"])}
    end

    def render(assigns) do
      ~H"""
      <div>
        <.live_component module={PostFormComponent} id="post-form" current_user={@current_user} />
      </div>
      """
    end
  end

  describe "post form component" do
    test "renders form with disabled state when no user is logged in" do
      html =
        render_component(PostFormComponent,
          id: "test",
          current_user: nil,
          content: "",
          char_count: 280,
          valid?: false,
          __changed__: %{}
        )

      # Check specific elements for disabled state
      assert html =~ ~s(textarea rows="3" name="content" id="content")
      assert html =~ "disabled"
      assert html =~ "Sign in to post"
      assert html =~ "You must be logged in to post"
    end

    test "validates content length" do
      html =
        render_component(PostFormComponent,
          id: "test",
          current_user: %{id: 1, avatar_url: nil},
          content: "",
          char_count: 280,
          valid?: false,
          __changed__: %{}
        )

      # Check submit button is disabled when content is empty
      assert html =~ ~s(button type="submit" disabled)
    end

    test "creates post with valid content" do
      user = user_fixture()
      socket = %Phoenix.LiveView.Socket{}
      socket = assign(socket,
        current_user: user,
        content: "Test post content",
        char_count: 280,
        valid?: true,
        __changed__: %{}
      )

      {:noreply, updated_socket} = PostFormComponent.handle_event(
        "create_post",
        %{"content" => "Test post content"},
        socket
      )

      assert updated_socket.assigns.content == ""
      assert updated_socket.assigns.char_count == 0
      assert updated_socket.assigns.loading == false

      # Verify post was created
      assert [post] = CursorDemo.Timeline.list_posts()
      assert post.content == "Test post content"
      assert post.user_id == user.id
    end

    test "shows error message when post creation fails" do
      user = user_fixture()
      html = render_component(PostFormComponent,
        id: "test",
        current_user: user,
        content: "",
        char_count: 0,
        valid?: false,
        error: "can't be blank"
      )

      assert html =~ "can&#39;t be blank"
    end

    test "updates character count in real-time" do
      user = user_fixture()

      # Test different content lengths and verify counter colors
      html = render_component(PostFormComponent,
        id: "test",
        current_user: user,
        content: "",
        char_count: 0,
        valid?: false
      )
      assert html =~ "text-gray-400"

      html = render_component(PostFormComponent,
        id: "test",
        current_user: user,
        content: "Hello",
        char_count: 5,
        valid?: true
      )
      assert html =~ "text-gray-500"

      html = render_component(PostFormComponent,
        id: "test",
        current_user: user,
        content: String.duplicate("a", 245),
        char_count: 245,
        valid?: true
      )
      assert html =~ "text-yellow-500"

      html = render_component(PostFormComponent,
        id: "test",
        current_user: user,
        content: String.duplicate("a", 275),
        char_count: 275,
        valid?: true
      )
      assert html =~ "text-red-500"
    end
  end
end
