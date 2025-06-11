no like write in text

Here is the structure of all your tables in the public schema, described in text format:

chats:

chat_id: UUID (Primary Key)
user_one_id: UUID (Foreign Key referencing auth.users)
created_at: Timestamp with time zone (default: now())
user_two_id: UUID
Indexes:
chat_id
user_one_id


device_tokens:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
token: Text
platform: Text
device_details: Text
last_seen: Timestamp with time zone (default: now())
created_at: Timestamp with time zone (default: now())
Indexes:
user_id
token

feed_queue:

user_id: UUID (Foreign Key referencing profiles)
post_id: UUID (Foreign Key referencing posts)
score: Numeric (default: 0.0)
queued_at: Timestamp with time zone (default: now())
consumed: Boolean (default: false)
Primary Key: (user_id, post_id)
Indexes:
user_id, consumed, score, queued_at

follows:

id: UUID (Primary Key)
follower_id: UUID (Foreign Key referencing auth.users)
following_id: UUID (Foreign Key referencing auth.users)
created_at: Timestamp with time zone (default: now())
Indexes:
follower_id
following_id

group_messages:

id: UUID (Primary Key)
group_id: UUID (Foreign Key referencing groups)
sender_id: UUID (Foreign Key referencing auth.users)
content: Text
message_type: Varchar (default: 'text')
created_at: Timestamp with time zone (default: now())
expires_at: Timestamp with time zone (default: now() + 24 hours)
is_encrypted: Boolean (default: true)
is_edited: Boolean (default: false)
read_by: JSONB (default: empty JSON)
Indexes:
group_id
sender_id
created_at
expires_at
read_by

groups:

id: UUID (Primary Key)
name: Varchar (not null)
description: Text
icon_url: Text
created_by: UUID (Foreign Key referencing auth.users)
created_at: Timestamp with time zone (default: now())
updated_at: Timestamp with time zone (default: now())
is_active: Boolean (default: true)
max_members: Integer (default: 100)
members: JSONB (default: empty JSON)
settings: JSONB (default: JSON with encryption settings)
Indexes:
created_by
is_active
members

messages:

message_id: UUID (Primary Key)
chat_id: UUID (Foreign Key referencing chats)
sender_id: UUID (Foreign Key referencing auth.users)
content: Text
created_at: Timestamp with time zone (default: now())
expires_at: Timestamp with time zone (not null)
is_read: Boolean (default: false)
message_type: Text (default: 'text')
recipient_id: UUID
Indexes:
chat_id

notification_logs:

id: UUID (Primary Key)
notification_id: UUID (Foreign Key referencing notifications)
event: Text (not null)
details: JSONB (nullable)
created_at: Timestamp with time zone (default: now())
Indexes:
notification_id

notifications:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
actor_id: UUID (Foreign Key referencing auth.users)
actor_username: Text (not null)
actor_nickname: Text (not null)
actor_avatar: Text (nullable)
type: Text (not null)
post_id: UUID (Foreign Key referencing posts, nullable)
comment_id: UUID (nullable)
message: Text (nullable)
is_read: Boolean (default: false)
created_at: Timestamp with time zone (not null)
Indexes:
user_id
created_at
is_read
actor_id

post_comment_likes:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
comment_id: UUID (Foreign Key referencing post_comments)
created_at: Timestamp with time zone (default: now())
Indexes:
user_id
comment_id

post_comments:

id: UUID (Primary Key)
post_id: UUID (Foreign Key referencing posts)
user_id: UUID (Foreign Key referencing auth.users)
content: Text (not null)
created_at: Timestamp with time zone (default: now())
updated_at: Timestamp with time zone (default: now())
is_deleted: Boolean (default: false)
parent_id: UUID (nullable, Foreign Key referencing post_comments)
likes: Integer (default: 0)
is_active: Boolean (default: true)
Indexes:
post_id
user_id
parent_id

post_likes:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
post_id: UUID (Foreign Key referencing posts)
created_at: Timestamp with time zone (default: now())
Indexes:
user_id
post_id

posts:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
content: Text (default: empty string)
image_url: Text (nullable)
gif_url: Text (nullable)
sticker_url: Text (nullable)
post_type: Text (not null)
metadata: JSONB (default: empty JSON)
created_at: Timestamp with time zone (not null)
updated_at: Timestamp with time zone (default: now())
likes_count: Integer (default: 0)
comments_count: Integer (default: 0)
views_count: Integer (default: 0)
shares_count: Integer (default: 0)
engagement_data: JSONB (default: empty JSON)
is_active: Boolean (default: true)
is_deleted: Boolean (default: false)
star_count: Integer (default: 0)
engagement_score: Numeric (default: 0.0)
virality_score: Numeric (default: 0.0)
last_engagement_update: Timestamp with time zone (default: now())
global: Boolean (default: false)
video_url: Text (nullable)
Indexes:
user_id
post_type
created_at

profiles:

username: Text (nullable, unique)
avatar: Text (nullable)
user_id: UUID (Primary Key, Foreign Key referencing auth.users)
nickname: Text (default: 'Yapper')
bio: Text (nullable)
userNameUpdate: Time without time zone (nullable)
updated_at: Timestamp with time zone (default: now())
follower_count: Integer (default: 0)
following_count: Integer (default: 0)
google_avatar: Text (default: empty string)
email: Text (nullable)
banner: Text (nullable)
has_active_story: Boolean (default: false)
latest_story_at: Timestamp with time zone (nullable)
post_count: Integer (default: 0)
Indexes:
has_active_story
latest_story_at

stories:

id: UUID (Primary Key)
user_id: UUID (Foreign Key referencing auth.users)
image_url: Text (nullable)
text_items: JSONB (default: empty JSON)
doodle_points: JSONB (default: empty JSON)
created_at: Timestamp with time zone (default: now())
expires_at: Timestamp with time zone (default: now() + 24 hours)
updated_at: