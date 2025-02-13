defmodule CursorDemoWeb.UserRegistrationController do
  use CursorDemoWeb, :controller

  alias CursorDemo.Accounts
  alias CursorDemo.Accounts.User
  alias CursorDemoWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        if Mix.env() in [:dev, :test] do
          conn
          |> UserAuth.log_in_user(user)
          |> redirect(to: ~p"/")
        else
          # In production, send confirmation email
          conn
          |> put_flash(:info, "Please check your email to confirm your account.")
          |> redirect(to: ~p"/login")
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account confirmed successfully.")
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      :error ->
        conn
        |> put_flash(:error, "Confirmation link is invalid or it has expired.")
        |> redirect(to: ~p"/")
    end
  end
end
