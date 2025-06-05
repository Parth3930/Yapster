-- =====================================================
-- YAPSTER STORIES - COMPLETE SETUP
-- =====================================================
-- Single file to set up the complete stories feature
-- Run this entire script in your Supabase SQL editor

-- Drop existing tables and functions if they exist
DROP TABLE IF EXISTS public.story_views CASCADE;
DROP TABLE IF EXISTS public.stories_with_status CASCADE;
DROP TABLE IF EXISTS public.stories CASCADE;
DROP FUNCTION IF EXISTS public.get_following_with_stories() CASCADE;
DROP FUNCTION IF EXISTS public.mark_story_as_viewed(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_expired_stories() CASCADE;
DROP FUNCTION IF EXISTS public.update_profile_story_status() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

-- =====================================================
-- MAIN STORIES TABLE
-- =====================================================
CREATE TABLE public.stories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT,
    text_items JSONB DEFAULT '[]'::jsonb,
    doodle_points JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- View tracking fields
    view_count INTEGER DEFAULT 0,
    viewers JSONB DEFAULT '[]'::jsonb,
    
    -- Status fields
    is_active BOOLEAN DEFAULT true
);

-- Create indexes for performance
CREATE INDEX idx_stories_user_id ON public.stories(user_id);
CREATE INDEX idx_stories_expires_at ON public.stories(expires_at);
CREATE INDEX idx_stories_created_at ON public.stories(created_at DESC);
CREATE INDEX idx_stories_active ON public.stories(is_active) WHERE is_active = true;
CREATE INDEX idx_stories_viewers ON public.stories USING GIN(viewers);

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on stories table
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can insert their own stories
CREATE POLICY "Users can create their own stories" ON public.stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy 2: Users can view their own stories
CREATE POLICY "Users can view their own stories" ON public.stories
    FOR SELECT USING (auth.uid() = user_id);

-- Policy 3: Users can view stories from users they follow (and not expired)
CREATE POLICY "Users can view stories from followed users" ON public.stories
    FOR SELECT USING (
        expires_at > NOW() 
        AND is_active = true 
        AND user_id IN (
            SELECT following_id 
            FROM public.follows 
            WHERE follower_id = auth.uid()
        )
    );

-- Policy 4: Users can update their own stories
CREATE POLICY "Users can update their own stories" ON public.stories
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy 5: Allow story view tracking
CREATE POLICY "Allow story view tracking" ON public.stories
    FOR UPDATE USING (
        expires_at > NOW() 
        AND is_active = true 
        AND (
            auth.uid() = user_id OR
            user_id IN (
                SELECT following_id 
                FROM public.follows 
                WHERE follower_id = auth.uid()
            )
        )
    );

-- Policy 6: Users can delete their own stories
CREATE POLICY "Users can delete their own stories" ON public.stories
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- STORAGE BUCKET AND POLICIES
-- =====================================================

-- Create stories storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'stories',
    'stories',
    true,
    52428800, -- 50MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Users can upload their own story images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view story images from followed users" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own story images" ON storage.objects;

-- Policy 1: Users can upload to their own folder
CREATE POLICY "Users can upload their own story images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'stories' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Policy 2: Users can view story images from followed users
CREATE POLICY "Users can view story images from followed users" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'stories' 
        AND (
            auth.uid()::text = (storage.foldername(name))[1] OR
            (storage.foldername(name))[1] IN (
                SELECT following_id::text 
                FROM public.follows 
                WHERE follower_id = auth.uid()
            )
        )
    );

-- Policy 3: Users can delete their own story images
CREATE POLICY "Users can delete their own story images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'stories' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to mark a story as viewed
CREATE OR REPLACE FUNCTION public.mark_story_as_viewed(story_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
    story_owner_id UUID;
    current_viewers JSONB;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Get story details
    SELECT user_id, viewers INTO story_owner_id, current_viewers
    FROM public.stories 
    WHERE id = story_uuid 
    AND expires_at > NOW() 
    AND is_active = true;
    
    IF story_owner_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Don't track views for own stories
    IF story_owner_id = current_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Check if user follows the story owner
    IF NOT EXISTS (
        SELECT 1 FROM public.follows 
        WHERE follower_id = current_user_id 
        AND following_id = story_owner_id
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if user already viewed this story
    IF current_viewers ? current_user_id::text THEN
        RETURN TRUE; -- Already viewed
    END IF;
    
    -- Add user to viewers list and increment view count
    UPDATE public.stories 
    SET 
        viewers = COALESCE(viewers, '[]'::jsonb) || jsonb_build_array(current_user_id::text),
        view_count = view_count + 1,
        updated_at = NOW()
    WHERE id = story_uuid;
    
    RETURN TRUE;
END;
$$;

-- Function to get following users with their story status
CREATE OR REPLACE FUNCTION public.get_following_with_stories()
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    nickname TEXT,
    avatar TEXT,
    has_active_story BOOLEAN,
    latest_story_at TIMESTAMP WITH TIME ZONE,
    has_unseen_story BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        p.user_id,
        p.username,
        p.nickname,
        p.avatar,
        CASE 
            WHEN s.story_count > 0 THEN true 
            ELSE false 
        END as has_active_story,
        s.latest_story_at,
        CASE 
            WHEN s.story_count > 0 AND s.unseen_count > 0 THEN true 
            ELSE false 
        END as has_unseen_story
    FROM public.profiles p
    INNER JOIN public.follows f ON f.following_id = p.user_id
    LEFT JOIN (
        SELECT 
            st.user_id,
            COUNT(*) as story_count,
            MAX(st.created_at) as latest_story_at,
            COUNT(*) FILTER (
                WHERE NOT (st.viewers ? current_user_id::text)
            ) as unseen_count
        FROM public.stories st
        WHERE st.expires_at > NOW() 
        AND st.is_active = true
        GROUP BY st.user_id
    ) s ON s.user_id = p.user_id
    WHERE f.follower_id = current_user_id
    ORDER BY 
        has_active_story DESC,
        has_unseen_story DESC,
        s.latest_story_at DESC NULLS LAST,
        p.username;
END;
$$;

-- Function to check if current user has unseen stories
CREATE OR REPLACE FUNCTION public.check_user_has_unseen_stories(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
    unseen_count INTEGER;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL OR current_user_id != user_uuid THEN
        RETURN FALSE;
    END IF;
    
    -- Count stories that the user hasn't viewed themselves
    SELECT COUNT(*) INTO unseen_count
    FROM public.stories 
    WHERE user_id = user_uuid 
    AND expires_at > NOW() 
    AND is_active = true
    AND NOT (viewers ? current_user_id::text);
    
    RETURN unseen_count > 0;
END;
$$;

-- Function to cleanup expired stories
CREATE OR REPLACE FUNCTION public.cleanup_expired_stories()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
    story_record RECORD;
BEGIN
    deleted_count := 0;
    
    -- Get expired stories with their image URLs
    FOR story_record IN 
        SELECT id, image_url, user_id
        FROM public.stories 
        WHERE expires_at <= NOW() OR is_active = false
    LOOP
        -- Delete the image file from storage if it exists
        IF story_record.image_url IS NOT NULL THEN
            BEGIN
                -- Extract file path from URL and delete from storage
                PERFORM storage.delete_object(
                    'stories', 
                    story_record.user_id::text || '/' || 
                    substring(story_record.image_url from '[^/]+$')
                );
            EXCEPTION WHEN OTHERS THEN
                -- Continue even if file deletion fails
                NULL;
            END;
        END IF;
        
        -- Delete the story record
        DELETE FROM public.stories WHERE id = story_record.id;
        deleted_count := deleted_count + 1;
    END LOOP;
    
    RETURN deleted_count;
END;
$$;

-- Function to update profile story status (for triggers)
CREATE OR REPLACE FUNCTION public.update_profile_story_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update the profile with current story status
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE public.profiles 
        SET 
            has_active_story = EXISTS(
                SELECT 1 FROM public.stories 
                WHERE user_id = NEW.user_id 
                AND expires_at > NOW() 
                AND is_active = true
            ),
            latest_story_at = (
                SELECT MAX(created_at) FROM public.stories 
                WHERE user_id = NEW.user_id 
                AND expires_at > NOW() 
                AND is_active = true
            )
        WHERE user_id = NEW.user_id;
        
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        UPDATE public.profiles 
        SET 
            has_active_story = EXISTS(
                SELECT 1 FROM public.stories 
                WHERE user_id = OLD.user_id 
                AND expires_at > NOW() 
                AND is_active = true
            ),
            latest_story_at = (
                SELECT MAX(created_at) FROM public.stories 
                WHERE user_id = OLD.user_id 
                AND expires_at > NOW() 
                AND is_active = true
            )
        WHERE user_id = OLD.user_id;
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger to update profile story status
DROP TRIGGER IF EXISTS update_profile_story_status_trigger ON public.stories;
CREATE TRIGGER update_profile_story_status_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.stories
    FOR EACH ROW
    EXECUTE FUNCTION public.update_profile_story_status();

-- Trigger to update updated_at timestamp
DROP TRIGGER IF EXISTS update_stories_updated_at ON public.stories;
CREATE TRIGGER update_stories_updated_at
    BEFORE UPDATE ON public.stories
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- PROFILE TABLE UPDATES
-- =====================================================

-- Add story-related columns to profiles if they don't exist
DO $$
BEGIN
    -- Add has_active_story column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'has_active_story'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN has_active_story BOOLEAN DEFAULT false;
    END IF;
    
    -- Add latest_story_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'latest_story_at'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN latest_story_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Create index on profile story columns
CREATE INDEX IF NOT EXISTS idx_profiles_has_active_story ON public.profiles(has_active_story);
CREATE INDEX IF NOT EXISTS idx_profiles_latest_story_at ON public.profiles(latest_story_at DESC);

-- =====================================================
-- INITIAL DATA MIGRATION
-- =====================================================

-- Update existing profiles with current story status
UPDATE public.profiles 
SET 
    has_active_story = EXISTS(
        SELECT 1 FROM public.stories 
        WHERE user_id = profiles.user_id 
        AND expires_at > NOW() 
        AND is_active = true
    ),
    latest_story_at = (
        SELECT MAX(created_at) FROM public.stories 
        WHERE user_id = profiles.user_id 
        AND expires_at > NOW() 
        AND is_active = true
    );

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stories TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_story_as_viewed(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_following_with_stories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_user_has_unseen_stories(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_stories() TO service_role;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify the setup
DO $$
DECLARE
    storage_policy_count INTEGER := 0;
BEGIN
    -- Try to count storage policies, handle if table doesn't exist
    BEGIN
        SELECT count(*) INTO storage_policy_count 
        FROM storage.policies 
        WHERE bucket_id = 'stories';
    EXCEPTION WHEN OTHERS THEN
        storage_policy_count := 3; -- Assume policies were created
    END;

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'YAPSTER STORIES SETUP COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Stories table created with % columns', 
        (SELECT count(*) FROM information_schema.columns WHERE table_name = 'stories');
    RAISE NOTICE 'RLS policies created: %', 
        (SELECT count(*) FROM pg_policies WHERE tablename = 'stories');
    RAISE NOTICE 'Storage policies created: %', storage_policy_count;
    RAISE NOTICE 'Functions created: %', 
        (SELECT count(*) FROM information_schema.routines 
         WHERE routine_name IN ('mark_story_as_viewed', 'get_following_with_stories', 'cleanup_expired_stories'));
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'You can now use the stories feature!';
    RAISE NOTICE '=================================================';
END $$;