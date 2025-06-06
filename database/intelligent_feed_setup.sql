-- =====================================================
-- INTELLIGENT FEED SYSTEM SETUP
-- =====================================================

-- Drop existing tables and functions if they exist
DROP TABLE IF EXISTS public.user_interactions CASCADE;
DROP FUNCTION IF EXISTS public.get_intelligent_posts_feed(UUID, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.update_post_engagement_score(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_interaction_summary(UUID) CASCADE;

-- =====================================================
-- USER INTERACTIONS TABLE
-- =====================================================
CREATE TABLE public.user_interactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- 'view', 'like', 'unlike', 'comment', 'share', 'time_spent'
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique interaction per user/post/type combination for some types
    UNIQUE(user_id, post_id, interaction_type, created_at)
);

-- Create indexes for performance
CREATE INDEX idx_user_interactions_user_id ON public.user_interactions(user_id);
CREATE INDEX idx_user_interactions_post_id ON public.user_interactions(post_id);
CREATE INDEX idx_user_interactions_type ON public.user_interactions(interaction_type);
CREATE INDEX idx_user_interactions_created_at ON public.user_interactions(created_at);
CREATE INDEX idx_user_interactions_metadata ON public.user_interactions USING GIN(metadata);

-- =====================================================
-- ENHANCED POSTS TABLE UPDATES
-- =====================================================

-- Add engagement score column to posts if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'engagement_score') THEN
        ALTER TABLE public.posts ADD COLUMN engagement_score DECIMAL(5,2) DEFAULT 0.0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'virality_score') THEN
        ALTER TABLE public.posts ADD COLUMN virality_score DECIMAL(5,2) DEFAULT 0.0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'last_engagement_update') THEN
        ALTER TABLE public.posts ADD COLUMN last_engagement_update TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Create index on engagement scores
CREATE INDEX IF NOT EXISTS idx_posts_engagement_score ON public.posts(engagement_score DESC);
CREATE INDEX IF NOT EXISTS idx_posts_virality_score ON public.posts(virality_score DESC);

-- =====================================================
-- INTELLIGENT FEED FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_intelligent_posts_feed(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    content TEXT,
    post_type VARCHAR(50),
    image_url TEXT,
    gif_url TEXT,
    sticker_url TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    likes_count INTEGER,
    comments_count INTEGER,
    views_count INTEGER,
    shares_count INTEGER,
    engagement_data JSONB,
    engagement_score DECIMAL(5,2),
    virality_score DECIMAL(5,2),
    username TEXT,
    nickname TEXT,
    avatar TEXT,
    google_avatar TEXT,
    calculated_score DECIMAL(8,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_time TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    RETURN QUERY
    WITH user_preferences AS (
        -- Calculate user preferences based on interactions
        SELECT 
            ui.user_id,
            (ui.metadata->>'post_type')::TEXT as preferred_post_type,
            (ui.metadata->>'author_id')::UUID as preferred_author,
            COUNT(*) as interaction_count,
            AVG(CASE 
                WHEN ui.interaction_type = 'like' THEN 1.0
                WHEN ui.interaction_type = 'comment' THEN 2.0
                WHEN ui.interaction_type = 'share' THEN 3.0
                WHEN ui.interaction_type = 'view' THEN 0.1
                ELSE 0.0
            END) as preference_weight
        FROM public.user_interactions ui
        WHERE ui.user_id = p_user_id
        AND ui.created_at > current_time - INTERVAL '30 days'
        GROUP BY ui.user_id, ui.metadata->>'post_type', ui.metadata->>'author_id'
    ),
    viewed_posts AS (
        -- Get posts user has already viewed
        SELECT DISTINCT ui.post_id
        FROM public.user_interactions ui
        WHERE ui.user_id = p_user_id
        AND ui.interaction_type = 'view'
        AND ui.created_at > current_time - INTERVAL '7 days'
    ),
    scored_posts AS (
        SELECT 
            p.*,
            prof.username,
            prof.nickname,
            prof.avatar,
            prof.google_avatar,
            -- Calculate comprehensive score
            (
                -- Engagement score (30%)
                COALESCE(p.engagement_score, 0) * 0.3 +
                
                -- Virality score (25%)
                COALESCE(p.virality_score, 0) * 0.25 +
                
                -- Freshness score (20%)
                CASE 
                    WHEN p.created_at > current_time - INTERVAL '1 hour' THEN 100
                    WHEN p.created_at > current_time - INTERVAL '6 hours' THEN 90 - EXTRACT(EPOCH FROM current_time - p.created_at) / 3600 * 2
                    WHEN p.created_at > current_time - INTERVAL '24 hours' THEN 80 - EXTRACT(EPOCH FROM current_time - p.created_at) / 3600 * 2
                    WHEN p.created_at > current_time - INTERVAL '72 hours' THEN 50 - EXTRACT(EPOCH FROM current_time - p.created_at) / 3600 * 0.5
                    ELSE GREATEST(10, 50 - EXTRACT(EPOCH FROM current_time - p.created_at) / 3600 * 0.1)
                END * 0.2 +
                
                -- Personalization score (20%)
                (
                    50 + -- Base score
                    COALESCE((
                        SELECT AVG(up.preference_weight * 10)
                        FROM user_preferences up
                        WHERE up.preferred_post_type = p.post_type
                    ), 0) +
                    COALESCE((
                        SELECT AVG(up.preference_weight * 15)
                        FROM user_preferences up
                        WHERE up.preferred_author = p.user_id
                    ), 0)
                ) * 0.2 +
                
                -- Diversity score (5%)
                CASE 
                    WHEN p.post_type = 'text' THEN 55
                    WHEN p.post_type = 'image' THEN 50
                    WHEN p.post_type = 'gif' THEN 60
                    WHEN p.post_type = 'sticker' THEN 65
                    ELSE 50
                END * 0.05
            ) as calculated_score
        FROM public.posts p
        INNER JOIN public.profiles prof ON prof.user_id = p.user_id
        WHERE p.is_active = true
        AND p.is_deleted = false
        AND p.user_id != p_user_id -- Exclude user's own posts
        AND p.id NOT IN (SELECT post_id FROM viewed_posts) -- Exclude viewed posts
        AND p.created_at > current_time - INTERVAL '7 days' -- Only recent posts
    )
    SELECT 
        sp.id,
        sp.user_id,
        sp.content,
        sp.post_type,
        sp.image_url,
        sp.gif_url,
        sp.sticker_url,
        sp.metadata,
        sp.created_at,
        sp.updated_at,
        sp.likes_count,
        sp.comments_count,
        sp.views_count,
        sp.shares_count,
        sp.engagement_data,
        sp.engagement_score,
        sp.virality_score,
        sp.username,
        sp.nickname,
        sp.avatar,
        sp.google_avatar,
        sp.calculated_score
    FROM scored_posts sp
    ORDER BY sp.calculated_score DESC, sp.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- =====================================================
-- ENGAGEMENT SCORE UPDATE FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_post_engagement_score(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    post_record RECORD;
    engagement_score DECIMAL(5,2);
    virality_score DECIMAL(5,2);
    current_time TIMESTAMP WITH TIME ZONE := NOW();
    post_age_hours DECIMAL;
BEGIN
    -- Get post data
    SELECT * INTO post_record
    FROM public.posts
    WHERE id = p_post_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Calculate post age in hours
    post_age_hours := EXTRACT(EPOCH FROM current_time - post_record.created_at) / 3600;
    
    -- Calculate engagement score
    engagement_score := (
        post_record.likes_count * 1.0 +
        post_record.comments_count * 3.0 +
        post_record.shares_count * 5.0 +
        post_record.views_count * 0.1
    ) / GREATEST(post_record.views_count, 1) * 100;
    
    -- Calculate virality score
    IF post_age_hours > 0 THEN
        virality_score := (
            (post_record.likes_count + post_record.comments_count + post_record.shares_count) / post_age_hours
        ) * CASE 
            WHEN post_age_hours <= 24 THEN 2.0
            WHEN post_age_hours <= 72 THEN 1.5
            ELSE 1.0
        END * 10;
    ELSE
        virality_score := 0;
    END IF;
    
    -- Update post scores
    UPDATE public.posts
    SET 
        engagement_score = LEAST(engagement_score, 100),
        virality_score = LEAST(virality_score, 100),
        last_engagement_update = current_time
    WHERE id = p_post_id;
END;
$$;

-- =====================================================
-- USER INTERACTION SUMMARY FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_user_interaction_summary(p_user_id UUID)
RETURNS TABLE (
    total_interactions BIGINT,
    likes_count BIGINT,
    comments_count BIGINT,
    shares_count BIGINT,
    views_count BIGINT,
    preferred_content_types JSONB,
    preferred_authors JSONB,
    interaction_timeline JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_interactions,
        COUNT(*) FILTER (WHERE interaction_type = 'like') as likes_count,
        COUNT(*) FILTER (WHERE interaction_type = 'comment') as comments_count,
        COUNT(*) FILTER (WHERE interaction_type = 'share') as shares_count,
        COUNT(*) FILTER (WHERE interaction_type = 'view') as views_count,
        
        -- Preferred content types
        jsonb_object_agg(
            content_type_prefs.post_type,
            content_type_prefs.interaction_count
        ) FILTER (WHERE content_type_prefs.post_type IS NOT NULL) as preferred_content_types,
        
        -- Preferred authors
        jsonb_object_agg(
            author_prefs.author_id::TEXT,
            author_prefs.interaction_count
        ) FILTER (WHERE author_prefs.author_id IS NOT NULL) as preferred_authors,
        
        -- Interaction timeline (last 7 days)
        jsonb_object_agg(
            timeline.date_key,
            timeline.daily_count
        ) as interaction_timeline
        
    FROM public.user_interactions ui
    LEFT JOIN LATERAL (
        SELECT 
            ui2.metadata->>'post_type' as post_type,
            COUNT(*) as interaction_count
        FROM public.user_interactions ui2
        WHERE ui2.user_id = p_user_id
        AND ui2.metadata->>'post_type' IS NOT NULL
        GROUP BY ui2.metadata->>'post_type'
        ORDER BY interaction_count DESC
        LIMIT 5
    ) content_type_prefs ON true
    LEFT JOIN LATERAL (
        SELECT 
            (ui3.metadata->>'author_id')::UUID as author_id,
            COUNT(*) as interaction_count
        FROM public.user_interactions ui3
        WHERE ui3.user_id = p_user_id
        AND ui3.metadata->>'author_id' IS NOT NULL
        GROUP BY ui3.metadata->>'author_id'
        ORDER BY interaction_count DESC
        LIMIT 5
    ) author_prefs ON true
    LEFT JOIN LATERAL (
        SELECT 
            DATE(ui4.created_at) as date_key,
            COUNT(*) as daily_count
        FROM public.user_interactions ui4
        WHERE ui4.user_id = p_user_id
        AND ui4.created_at > NOW() - INTERVAL '7 days'
        GROUP BY DATE(ui4.created_at)
    ) timeline ON true
    WHERE ui.user_id = p_user_id;
END;
$$;

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on user_interactions table
ALTER TABLE public.user_interactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own interactions
CREATE POLICY "Users can manage their own interactions" ON public.user_interactions
    FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger to update engagement scores when posts are updated
CREATE OR REPLACE FUNCTION update_post_engagement_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Update engagement score when engagement counts change
    IF (OLD.likes_count != NEW.likes_count OR 
        OLD.comments_count != NEW.comments_count OR 
        OLD.shares_count != NEW.shares_count OR 
        OLD.views_count != NEW.views_count) THEN
        
        PERFORM update_post_engagement_score(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS update_post_engagement_scores ON public.posts;
CREATE TRIGGER update_post_engagement_scores
    AFTER UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION update_post_engagement_trigger();

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_interactions TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_intelligent_posts_feed(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_post_engagement_score(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_interaction_summary(UUID) TO authenticated;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    interaction_table_count INTEGER;
    function_count INTEGER;
    policy_count INTEGER;
BEGIN
    -- Check if table was created
    SELECT COUNT(*) INTO interaction_table_count
    FROM information_schema.tables 
    WHERE table_name = 'user_interactions' AND table_schema = 'public';
    
    -- Check if functions were created
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_name IN ('get_intelligent_posts_feed', 'update_post_engagement_score', 'get_user_interaction_summary')
    AND routine_schema = 'public';
    
    -- Check if policies were created
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'user_interactions';
    
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'INTELLIGENT FEED SETUP COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'User interactions table created: %', CASE WHEN interaction_table_count > 0 THEN 'YES' ELSE 'NO' END;
    RAISE NOTICE 'Functions created: %', function_count;
    RAISE NOTICE 'RLS policies created: %', policy_count;
    RAISE NOTICE '=================================================';
END;
$$;
