defmodule CursorDemo.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows) do
      add :follower_id, references(:users, on_delete: :delete_all), null: false
      add :followed_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:follows, [:follower_id])
    create index(:follows, [:followed_id])
    create unique_index(:follows, [:follower_id, :followed_id], name: :follows_follower_id_followed_id_index)

    # Prevent users from following themselves
    create constraint(:follows, :cannot_follow_self, check: "follower_id != followed_id")
  end
end
