defmodule CursorDemoWeb.PageControllerTest do
  use CursorDemoWeb.ConnCase

  import Phoenix.LiveViewTest
  import CursorDemo.AccountsFixtures

  describe "landing page" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/")
    end

    test "shows timeline when authenticated", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/")

      # Check for main navigation elements
      assert html =~ "Timeline"

      # Check for user presence
      assert html =~ user.username
    end
  end
end
