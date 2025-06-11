-- Migration: replace previous feed RPCs with single get_feed_for_user function
-- Drops old functions if they exist, then creates the new one.

-- 1. Drop legacy functions
DROP FUNCTION IF EXISTS public.intelligent_feed(uuid, int);
DROP FUNCTION IF EXISTS public.fallback_feed(uuid, int);
DROP FUNCTION IF EXISTS public.get_feed_for_user(uuid, int);

-- 2. Create unified feed function
CREATE OR REPLACE FUNCTION public.get_feed_for_user(
    _user uuid,
    _limit int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    user_id uuid,
    content text,
    image_url text,
    gif_url text,
    sticker_url text,
    post_type text,
    metadata jsonb,
    created_at timestamptz,
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
    LEFT JOIN public.user_interactions ui ON ui.user_id = _user AND ui.post_id = p.id
    WHERE fq.post_id IS NULL                       -- not queued yet
      AND ui.id IS NULL                            -- not interacted yet
      AND p.is_deleted = FALSE
      AND p.is_active  = TRUE
      AND p.user_id <> _user                       -- exclude own posts
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
        p.gif_url,
        p.sticker_url,
        p.post_type,
        p.metadata,
        p.created_at,
        fq.score
    FROM public.feed_queue fq
    JOIN public.posts p ON p.id = fq.post_id
    WHERE fq.user_id = _user
      AND fq.consumed = FALSE
    ORDER BY fq.score DESC, fq.queued_at
    LIMIT _limit;
END;
$$;
