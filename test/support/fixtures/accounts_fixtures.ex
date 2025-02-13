defmodule CursorDemo.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `CursorDemo.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@ictu.nl"
  def unique_username do
    # Generate a random string of 8 characters (letters and numbers)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16() |> String.downcase()
    "user_#{random}"
  end
  def valid_user_password, do: "Hello123!world"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      username: unique_username(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> CursorDemo.Accounts.register_user()

    user
  end

  def follow_fixture(%{follower: follower, followed: followed}) do
    {:ok, follow} = CursorDemo.Accounts.follow_user(follower, followed)
    follow
  end
end
