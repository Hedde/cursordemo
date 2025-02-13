defmodule CursorDemo.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :type, :string, null: false
      add :read_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :post_id, references(:posts, on_delete: :nilify_all)

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:actor_id])
    create index(:notifications, [:post_id])
    create index(:notifications, [:user_id, :read_at])
  end
end
