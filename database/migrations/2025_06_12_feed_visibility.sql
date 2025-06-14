-- Migration: Update feed visibility to properly handle global flag
-- This migration updates the get_feed_for_user function to ensure posts are only shown to followers unless they are global

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_feed_for_user(uuid, int);

-- Create updated function with proper visibility handling
CREATE OR REPLACE FUNCTION public.get_feed_for_user(
    _user uuid,
    _limit int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    user_id uuid,
    content text,
    image_url text,
    video_url text,
    gif_url text,
    sticker_url text,
    post_type text,
    metadata jsonb,
    created_at timestamptz,
    updated_at timestamptz,
    likes_count int,
    comments_count int,
    views_count int,
    shares_count int,
    star_count int,
    engagement_data jsonb,
    score numeric
)
LANGUAGE plpgsql SECURITY DEFINER AS
$$
BEGIN
    -- Populate feed_queue lazily
    INSERT INTO public.feed_queue (user_id, post_id, score)
    SELECT
        _user,
        p.id,
        -- Simple ranking: popularity (likes + comments*2) and freshness penalty
        (p.likes_count + p.comments_count * 2) * 0.3 +
        GREATEST(0, EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600 * -0.05)
    FROM public.posts p
    LEFT JOIN public.feed_queue fq ON fq.user_id = _user AND fq.post_id = p.id
    WHERE fq.post_id IS NULL                       -- not queued yet
      AND p.is_deleted = FALSE
      AND p.is_active  = TRUE
      AND p.user_id <> _user                       -- exclude own posts
      AND (
          -- Show global posts to everyone
          p.global = TRUE
          OR
          -- Show non-global posts only to followers
          EXISTS (
              SELECT 1 FROM public.follows f
              WHERE f.follower_id = _user AND f.following_id = p.user_id
          )
      )
    ORDER BY (
        SELECT 1 FROM public.follows f
          WHERE f.follower_id = _user AND f.following_id = p.user_id
    ) DESC NULLS LAST,
    (p.likes_count + p.comments_count * 2) DESC
    LIMIT 200;

    -- Return next slice
    RETURN QUERY
    SELECT
        p.id,
        p.user_id,
        p.content,
        p.image_url,
        p.video_url,
        p.gif_url,
        p.sticker_url,
        p.post_type,
        p.metadata,
        p.created_at,
        p.updated_at,
        p.likes_count,
        p.comments_count,
        p.views_count,
        p.shares_count,
        p.star_count,
        p.engagement_data,
        fq.score
    FROM public.feed_queue fq
    JOIN public.posts p ON p.id = fq.post_id
    WHERE fq.user_id = _user
      AND fq.consumed = FALSE
    ORDER BY fq.score DESC, fq.queued_at
    LIMIT _limit;
END;
$$;

-- Add comment to explain the function
COMMENT ON FUNCTION public.get_feed_for_user IS 'Returns posts for user feed with proper visibility handling. Global posts are shown to everyone, non-global posts are only shown to followers.';

-- Create index to optimize the visibility check
CREATE INDEX IF NOT EXISTS posts_visibility_idx ON public.posts (global, user_id, is_deleted, is_active);

-- Create index to optimize the follower check
CREATE INDEX IF NOT EXISTS follows_lookup_idx ON public.follows (follower_id, following_id);

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_feed_for_user TO authenticated; 