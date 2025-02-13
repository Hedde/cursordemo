defmodule CursorDemo.Repo do
  use Ecto.Repo,
    otp_app: :cursor_demo,
    adapter: Ecto.Adapters.Postgres
end
