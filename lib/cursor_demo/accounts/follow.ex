defmodule CursorDemo.Accounts.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, CursorDemo.Accounts.User
    belongs_to :followed, CursorDemo.Accounts.User

    timestamps()
  end

  @doc """
  Creates a follow changeset.
  """
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:followed_id)
    |> unique_constraint([:follower_id, :followed_id], name: :follows_follower_id_followed_id_index)
    |> check_constraint(:follower_id, name: :cannot_follow_self,
      check: "follower_id != followed_id",
      message: "users cannot follow themselves")
  end
end
