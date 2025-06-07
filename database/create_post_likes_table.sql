-- Create post_likes table for the new like system
-- This replaces the user_post_engagements table for likes functionality

CREATE TABLE IF NOT EXISTS post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent duplicate likes from the same user on the same post
    UNIQUE(user_id, post_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_created_at ON post_likes(created_at);

-- Enable RLS (Row Level Security)
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can only see and modify their own likes
CREATE POLICY "Users can view their own likes" ON post_likes
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own likes" ON post_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own likes" ON post_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, DELETE ON post_likes TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Note: No UPDATE policy needed since we only INSERT (like) and DELETE (unlike)
-- The created_at timestamp should not be modified after creation