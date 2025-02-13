defmodule CursorDemoWeb.UserSessionController do
  use CursorDemoWeb, :controller

  alias CursorDemo.Accounts
  alias CursorDemoWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new,
      error_message: nil,
      form: Phoenix.Component.to_form(%{"email" => nil, "password" => nil, "remember_me" => false})
    )
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      if user.confirmed_at || Mix.env() in [:dev, :test] do
        conn
        |> UserAuth.log_in_user(user, user_params)
        |> redirect(to: ~p"/")
      else
        render(conn, :new,
          error_message: "You must confirm your email address before signing in.",
          form: Phoenix.Component.to_form(%{"email" => email, "remember_me" => user_params["remember_me"] || false})
        )
      end
    else
      render(conn, :new,
        error_message: "Invalid email or password",
        form: Phoenix.Component.to_form(%{"email" => email, "remember_me" => user_params["remember_me"] || false})
      )
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> redirect(to: ~p"/login")
  end
end
