defmodule CursorDemo.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :content, :string
      add :image_url, :string
      add :deleted_at, :utc_datetime
      add :parent_post_id, references(:posts, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:parent_post_id])
    create index(:posts, [:user_id])
  end
end
