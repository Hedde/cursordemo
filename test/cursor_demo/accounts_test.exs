defmodule CursorDemo.AccountsTest do
  use CursorDemo.DataCase, async: true

  alias CursorDemo.Accounts
  alias CursorDemo.Accounts.User

  import CursorDemo.AccountsFixtures

  describe "users" do
    @valid_attrs %{
      email: "test@ictu.nl",
      username: "testuser",
      password: "Password123!"
    }
    @update_attrs %{
      bio: "Updated bio",
      location: "New Location",
      website: "https://example.com"
    }
    @invalid_attrs %{email: nil, username: nil, password: nil}

    test "list_users/0 returns all non-deleted users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]

      # Test that deleted users are not returned
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.list_users() == []
    end

    test "get_user/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user(user.id) == user

      # Test that deleted users are not returned
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.get_user(user.id) == nil
    end

    test "get_user_by_email/1 returns the user with given email" do
      user = user_fixture()
      assert Accounts.get_user_by_email(user.email) == user

      # Test that deleted users are not returned
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.get_user_by_email(user.email) == nil
    end

    test "get_user_by_username/1 returns the user with given username" do
      user = user_fixture()
      assert Accounts.get_user_by_username(user.username) == user

      # Test that deleted users are not returned
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.get_user_by_username(user.username) == nil
    end

    test "register_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_attrs)
      assert user.email == "test@ictu.nl"
      assert user.username == "testuser"
      assert Bcrypt.verify_pass("Password123!", user.password_hash)
    end

    test "register_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(@invalid_attrs)
    end

    test "register_user/1 enforces unique email" do
      assert {:ok, %User{}} = Accounts.register_user(@valid_attrs)
      assert {:error, changeset} = Accounts.register_user(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "register_user/1 enforces unique username" do
      assert {:ok, %User{}} = Accounts.register_user(@valid_attrs)
      attrs = %{@valid_attrs | email: "other@example.com"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "has already been taken" in errors_on(changeset).username
    end

    test "register_user/1 only allows @ictu.nl email addresses" do
      invalid_email_attrs = %{@valid_attrs | email: "test@example.com"}
      assert {:error, changeset} = Accounts.register_user(invalid_email_attrs)
      assert "must be an @ictu.nl email address" in errors_on(changeset).email

      valid_email_attrs = %{@valid_attrs | email: "test@ictu.nl"}
      assert {:ok, %User{}} = Accounts.register_user(valid_email_attrs)
    end

    test "update_user_profile/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = Accounts.update_user_profile(user, @update_attrs)
      assert user.bio == "Updated bio"
      assert user.location == "New Location"
      assert user.website == "https://example.com"
    end

    test "update_user_profile/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user_profile(user, %{bio: String.duplicate("a", 161)})
      assert user == Accounts.get_user(user.id)
    end

    test "delete_user/1 soft deletes a user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert nil == Accounts.get_user(user.id)
    end

    test "change_user/2 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "follows" do
    setup do
      follower = user_fixture()
      followed = user_fixture()
      %{follower: follower, followed: followed}
    end

    test "list_followers/1 returns all followers of a user", %{follower: follower, followed: followed} do
      assert Accounts.list_followers(followed) == []
      {:ok, _follow} = Accounts.follow_user(follower, followed)
      assert Accounts.list_followers(followed) == [follower]
    end

    test "list_following/1 returns all users a user is following", %{follower: follower, followed: followed} do
      assert Accounts.list_following(follower) == []
      {:ok, _follow} = Accounts.follow_user(follower, followed)
      assert Accounts.list_following(follower) == [followed]
    end

    test "follow_user/2 creates a follow relationship", %{follower: follower, followed: followed} do
      assert {:ok, follow} = Accounts.follow_user(follower, followed)
      assert follow.follower_id == follower.id
      assert follow.followed_id == followed.id
    end

    test "follow_user/2 prevents self-following", %{follower: user} do
      assert {:error, changeset} = Accounts.follow_user(user, user)
      assert "users cannot follow themselves" in errors_on(changeset).follower_id
    end

    test "follow_user/2 prevents duplicate follows", %{follower: follower, followed: followed} do
      assert {:ok, _} = Accounts.follow_user(follower, followed)
      assert {:error, changeset} = Accounts.follow_user(follower, followed)
      assert "has already been taken" in errors_on(changeset).follower_id
    end

    test "unfollow_user/2 removes a follow relationship", %{follower: follower, followed: followed} do
      {:ok, _} = Accounts.follow_user(follower, followed)
      assert :ok = Accounts.unfollow_user(follower, followed)
      assert Accounts.list_followers(followed) == []
    end

    test "unfollow_user/2 returns error when follow doesn't exist", %{follower: follower, followed: followed} do
      assert {:error, :not_found} = Accounts.unfollow_user(follower, followed)
    end

    test "following?/2 returns true for existing follow", %{follower: follower, followed: followed} do
      refute Accounts.following?(follower, followed)
      {:ok, _} = Accounts.follow_user(follower, followed)
      assert Accounts.following?(follower, followed)
    end
  end
end
