-- Fixed Like/Unlike System
-- This function properly handles likes/unlikes using post_likes table
-- 
-- Required table structure for post_likes:
-- CREATE TABLE post_likes (
--     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
--     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
--     post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
--     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
--     UNIQUE(user_id, post_id) -- Prevent duplicate likes
-- );

CREATE OR REPLACE FUNCTION toggle_post_like(
    p_post_id UUID,
    p_user_id UUID
)
RETURNS TABLE(
    is_liked BOOLEAN,
    new_likes_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_like_state BOOLEAN := FALSE;
    new_count INTEGER;
BEGIN
    -- Check if user has already liked this post
    SELECT EXISTS(
        SELECT 1 FROM post_likes
        WHERE post_id = p_post_id AND user_id = p_user_id
    ) INTO current_like_state;

    IF current_like_state THEN
        -- User is unliking the post
        
        -- Remove like from post_likes table
        DELETE FROM post_likes
        WHERE post_id = p_post_id AND user_id = p_user_id;
        
        -- Decrement likes_count in posts table
        UPDATE posts
        SET likes_count = GREATEST(0, COALESCE(likes_count, 0) - 1),
            updated_at = NOW()
        WHERE id = p_post_id;
        
        -- Remove like interaction from user_interactions table
        DELETE FROM user_interactions
        WHERE post_id = p_post_id 
        AND user_id = p_user_id 
        AND interaction_type = 'like';
        
        -- Get updated count
        SELECT COALESCE(likes_count, 0) INTO new_count
        FROM posts WHERE id = p_post_id;
        
        RETURN QUERY SELECT FALSE, new_count;
        
    ELSE
        -- User is liking the post
        
        -- Add like to post_likes table
        INSERT INTO post_likes (user_id, post_id, created_at)
        VALUES (p_user_id, p_post_id, NOW())
        ON CONFLICT (user_id, post_id) DO NOTHING; -- Prevent duplicates
        
        -- Increment likes_count in posts table
        UPDATE posts
        SET likes_count = COALESCE(likes_count, 0) + 1,
            updated_at = NOW()
        WHERE id = p_post_id;
        
        -- Remove any existing unlike interaction and add like interaction
        DELETE FROM user_interactions
        WHERE post_id = p_post_id 
        AND user_id = p_user_id 
        AND interaction_type IN ('like', 'unlike');
        
        INSERT INTO user_interactions (user_id, post_id, interaction_type, metadata)
        VALUES (p_user_id, p_post_id, 'like', jsonb_build_object(
            'timestamp', NOW()::text,
            'post_type', (SELECT post_type FROM posts WHERE id = p_post_id),
            'author_id', (SELECT user_id FROM posts WHERE id = p_post_id)
        ));
        
        -- Get updated count
        SELECT COALESCE(likes_count, 0) INTO new_count
        FROM posts WHERE id = p_post_id;
        
        RETURN QUERY SELECT TRUE, new_count;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return current state
        RAISE WARNING 'Error in toggle_post_like: %', SQLERRM;
        
        -- Return current state as fallback
        SELECT COALESCE(likes_count, 0) INTO new_count
        FROM posts WHERE id = p_post_id;
        
        RETURN QUERY SELECT current_like_state, new_count;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION toggle_post_like(UUID, UUID) TO authenticated;

-- Function to get current like state for a user and post
CREATE OR REPLACE FUNCTION get_user_post_like_state(
    p_post_id UUID,
    p_user_id UUID
)
RETURNS TABLE(
    is_liked BOOLEAN,
    likes_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXISTS(
            SELECT 1 FROM post_likes 
            WHERE post_id = p_post_id AND user_id = p_user_id
        ) as is_liked,
        COALESCE(p.likes_count, 0) as likes_count
    FROM posts p
    WHERE p.id = p_post_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_post_like_state(UUID, UUID) TO authenticated;