defmodule CursorDemo.Timeline.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias CursorDemo.Timeline.Like
  alias CursorDemo.Accounts.User

  @max_content_length 500

  schema "posts" do
    field :content, :string
    field :image_url, :string
    field :deleted_at, :utc_datetime
    field :likes_count, :integer, default: 0
    field :reposts_count, :integer, default: 0

    belongs_to :parent_post, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_post_id

    belongs_to :user, User
    has_many :likes, Like

    timestamps()
  end

  @doc """
  Creates a post changeset.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :image_url, :user_id, :parent_post_id])
    |> validate_required([:content, :user_id])
    |> validate_length(:content, min: 1, max: @max_content_length, message: "must be between 1 and #{@max_content_length} characters")
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_post_id)
  end

  @doc """
  Marks a post as deleted.
  """
  def delete_changeset(post) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(post, deleted_at: now)
  end
end
