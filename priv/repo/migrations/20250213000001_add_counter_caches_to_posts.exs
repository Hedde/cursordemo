defmodule CursorDemo.Repo.Migrations.AddCounterCachesToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :likes_count, :integer, default: 0, null: false
      add :reposts_count, :integer, default: 0, null: false
    end
  end
end
