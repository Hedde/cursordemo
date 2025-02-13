Based on your requirements, I'll outline the data model structure we'll implement. We'll use Phoenix's built-in authentication, implement PubSub for real-time features, and include soft deletion. Here's the detailed plan:

1. **Schema Definitions**

```elixir
# Users Schema
defmodule CursorDemo.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :avatar_url, :string
    
    # Profile fields embedded in users table for simplicity
    field :bio, :string
    field :location, :string
    field :website, :string
    
    # Soft deletion and timestamps
    field :deleted_at, :utc_datetime
    timestamps()

    # Relationships
    has_many :posts, CursorDemo.Timeline.Post
    has_many :likes, CursorDemo.Timeline.Like
    has_many :notifications, CursorDemo.Notifications.Notification
    
    # Follow relationships
    has_many :following, CursorDemo.Accounts.Follow, foreign_key: :follower_id
    has_many :followers, CursorDemo.Accounts.Follow, foreign_key: :followed_id
  end
end

# Posts Schema
defmodule CursorDemo.Timeline.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    field :image_url, :string
    field :deleted_at, :utc_datetime
    
    # For reply functionality
    belongs_to :parent_post, CursorDemo.Timeline.Post
    has_many :replies, CursorDemo.Timeline.Post, foreign_key: :parent_post_id
    
    belongs_to :user, CursorDemo.Accounts.User
    has_many :likes, CursorDemo.Timeline.Like
    
    timestamps()
  end
end

# Likes Schema
defmodule CursorDemo.Timeline.Like do
  use Ecto.Schema
  import Ecto.Changeset

  schema "likes" do
    belongs_to :user, CursorDemo.Accounts.User
    belongs_to :post, CursorDemo.Timeline.Post
    
    timestamps()
  end
end

# Follows Schema
defmodule CursorDemo.Accounts.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, CursorDemo.Accounts.User
    belongs_to :followed, CursorDemo.Accounts.User
    
    timestamps()
  end
end

# Notifications Schema
defmodule CursorDemo.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string  # "like", "follow", "mention"
    field :read_at, :utc_datetime
    
    belongs_to :user, CursorDemo.Accounts.User
    belongs_to :actor, CursorDemo.Accounts.User
    belongs_to :post, CursorDemo.Timeline.Post
    
    timestamps()
  end
end
```

2. **PubSub Topics**
We'll define these topics for real-time updates:
- `user:#{user_id}` - For user-specific updates
- `timeline:#{user_id}` - For timeline updates
- `post:#{post_id}` - For post-specific updates (likes, replies)
- `notifications:#{user_id}` - For user notifications

3. **Broadcast Functions**
We'll implement these in their respective contexts:

```elixir
# In Timeline context
def broadcast_post(post) do
  Phoenix.PubSub.broadcast(CursorDemo.PubSub, "timeline:global", {:new_post, post})
  Phoenix.PubSub.broadcast(CursorDemo.PubSub, "user:#{post.user_id}", {:new_post, post})
end

def broadcast_like(like) do
  Phoenix.PubSub.broadcast(CursorDemo.PubSub, "post:#{like.post_id}", {:new_like, like})
end

# In Notifications context
def broadcast_notification(notification) do
  Phoenix.PubSub.broadcast(CursorDemo.PubSub, "notifications:#{notification.user_id}", {:new_notification, notification})
end
```

4. **Implementation Order**:
1. User authentication with Phoenix.Auth
2. Posts CRUD with image upload (using Waffle)
3. Follows functionality
4. Likes system
5. Reply functionality
6. Notifications system
7. PubSub implementations
8. Soft deletion implementation

Would you like me to start implementing these schemas and their migrations? We can begin with the User schema and authentication system, then move on to posts and other features incrementally. 