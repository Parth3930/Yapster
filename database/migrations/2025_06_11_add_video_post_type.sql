-- Migration: Add 'video' to allowed post_type values
-- Adjust the check constraint on posts.post_type to include 'video'

ALTER TABLE posts
DROP CONSTRAINT IF EXISTS posts_post_type_check;

ALTER TABLE posts
ADD CONSTRAINT posts_post_type_check
CHECK (post_type IN ('text', 'image', 'video', 'gif', 'sticker'));
