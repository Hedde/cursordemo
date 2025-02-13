# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CursorDemo.Repo.insert!(%CursorDemo.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias CursorDemo.{Accounts, Timeline}

# Create test users
users =
  Enum.map(1..5, fn i ->
    {:ok, user} =
      Accounts.register_user(%{
        username: "user#{i}",
        email: "user#{i}@ictu.nl",
        password: "Password123!",
        confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
    user
  end)

# Create some posts
Enum.each(0..20, fn _ ->
  user = Enum.random(users)
  Timeline.create_post(user, %{
    content: Faker.Lorem.paragraph()
  })
end)

# Create some replies
posts = Timeline.list_posts()
Enum.each(0..10, fn _ ->
  user = Enum.random(users)
  parent_post = Enum.random(posts)
  Timeline.create_post(user, %{
    content: Faker.Lorem.paragraph(),
    parent_post_id: parent_post.id
  })
end)

# Create some likes
Enum.each(posts, fn post ->
  # Each post gets 0-3 random likes
  Enum.each(Enum.take_random(users, Enum.random(0..3)), fn user ->
    Timeline.create_like(user, post)
  end)
end)

IO.puts "Database seeded successfully!"
