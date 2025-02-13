defmodule CursorDemo.Repo.Migrations.AddAuthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Email verification
      add :confirmed_at, :naive_datetime
      add :confirmation_token, :string
      add :confirmation_sent_at, :naive_datetime

      # Password reset
      add :reset_password_token, :string
      add :reset_password_sent_at, :naive_datetime

      # Session management
      add :last_sign_in_at, :naive_datetime
      add :last_sign_in_ip, :string
    end

    create unique_index(:users, [:confirmation_token])
    create unique_index(:users, [:reset_password_token])
  end
end
