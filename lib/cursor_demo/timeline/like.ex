defmodule CursorDemo.Timeline.Like do
  use Ecto.Schema
  import Ecto.Changeset

  schema "likes" do
    belongs_to :user, CursorDemo.Accounts.User
    belongs_to :post, CursorDemo.Timeline.Post

    timestamps()
  end

  @doc """
  Creates a like changeset.
  """
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :post_id], name: :likes_user_id_post_id_index)
  end
end
