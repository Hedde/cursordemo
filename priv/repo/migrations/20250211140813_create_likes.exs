defmodule CursorDemo.Repo.Migrations.CreateLikes do
  use Ecto.Migration

  def change do
    create table(:likes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:likes, [:user_id])
    create index(:likes, [:post_id])
    create unique_index(:likes, [:user_id, :post_id], name: :likes_user_id_post_id_index)
  end
end
