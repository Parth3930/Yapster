-- =====================================================
-- YAPSTER COMMENTS SYSTEM - COMPLETE SETUP
-- =====================================================
-- Single file to set up the complete comments feature
-- Run this entire script in your Supabase SQL editor

-- =====================================================
-- 1. CREATE COMMENTS TABLES
-- =====================================================

-- Main comments table (add missing columns if they don't exist)
DO $$
BEGIN
    -- Create table if it doesn't exist
    CREATE TABLE IF NOT EXISTS public.post_comments (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        parent_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE, -- For replies
        likes INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- Add missing columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_active') THEN
        ALTER TABLE public.post_comments ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_deleted') THEN
        ALTER TABLE public.post_comments ADD COLUMN is_deleted BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Comment likes table
CREATE TABLE IF NOT EXISTS public.post_comment_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    comment_id UUID NOT NULL REFERENCES public.post_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one like per user per comment
    UNIQUE(user_id, comment_id)
);

-- =====================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Comments indexes
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON public.post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent_id ON public.post_comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_created_at ON public.post_comments(created_at DESC);

-- Create index on is_active only if the column exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_active') THEN
        CREATE INDEX IF NOT EXISTS idx_post_comments_active ON public.post_comments(is_active) WHERE is_active = true;
    END IF;
END $$;

-- Comment likes indexes
CREATE INDEX IF NOT EXISTS idx_post_comment_likes_user_id ON public.post_comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_likes_comment_id ON public.post_comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_likes_created_at ON public.post_comment_likes(created_at DESC);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on both tables
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comment_likes ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. CREATE RLS POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view comments on posts they can see" ON public.post_comments;
DROP POLICY IF EXISTS "Users can create comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can update their own comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can delete their own comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can view comment likes" ON public.post_comment_likes;
DROP POLICY IF EXISTS "Users can like comments" ON public.post_comment_likes;
DROP POLICY IF EXISTS "Users can unlike their own likes" ON public.post_comment_likes;

-- Comments policies
CREATE POLICY "Users can view comments on posts they can see" ON public.post_comments
    FOR SELECT USING (
        (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_active') OR is_active = true)
        AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_deleted') OR is_deleted = false)
        AND post_id IN (
            SELECT id FROM public.posts
            WHERE (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'is_active') OR is_active = true)
            AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'is_deleted') OR is_deleted = false)
        )
    );

CREATE POLICY "Users can create comments" ON public.post_comments
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND post_id IN (
            SELECT id FROM public.posts
            WHERE (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'is_active') OR is_active = true)
            AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'is_deleted') OR is_deleted = false)
        )
    );

CREATE POLICY "Users can update their own comments" ON public.post_comments
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comments" ON public.post_comments
    FOR DELETE USING (auth.uid() = user_id);

-- Comment likes policies
CREATE POLICY "Users can view comment likes" ON public.post_comment_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can like comments" ON public.post_comment_likes
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND comment_id IN (
            SELECT id FROM public.post_comments
            WHERE (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_active') OR is_active = true)
            AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'post_comments' AND column_name = 'is_deleted') OR is_deleted = false)
        )
    );

CREATE POLICY "Users can unlike their own likes" ON public.post_comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 5. CREATE FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update comment likes count
CREATE OR REPLACE FUNCTION update_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.post_comments 
        SET likes = likes + 1 
        WHERE id = NEW.comment_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.post_comments 
        SET likes = likes - 1 
        WHERE id = OLD.comment_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update comment likes count
DROP TRIGGER IF EXISTS trigger_update_comment_likes_count ON public.post_comment_likes;
CREATE TRIGGER trigger_update_comment_likes_count
    AFTER INSERT OR DELETE ON public.post_comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_comment_likes_count();

-- Function to update post comments count
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts 
        SET comments_count = comments_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts 
        SET comments_count = comments_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update post comments count
DROP TRIGGER IF EXISTS trigger_update_post_comments_count ON public.post_comments;
CREATE TRIGGER trigger_update_post_comments_count
    AFTER INSERT OR DELETE ON public.post_comments
    FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.post_comments TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.post_comment_likes TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =====================================================
-- SETUP COMPLETE
-- =====================================================
-- Comments system is now ready to use!
-- Tables created: post_comments, post_comment_likes
-- Features: Comments, replies, likes, automatic counts
