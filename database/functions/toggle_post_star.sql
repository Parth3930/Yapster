-- Function to toggle post star (favorite) status
-- Similar to toggle_post_like but for stars/favorites
CREATE OR REPLACE FUNCTION public.toggle_post_star(
    p_post_id uuid,
    p_user_id uuid
)
RETURNS TABLE (
    is_starred boolean,
    star_count integer,
    status text,
    message text
)
LANGUAGE plpgsql SECURITY DEFINER AS
$$
DECLARE
    current_star_state BOOLEAN := FALSE;
    new_count INTEGER;
    v_status TEXT := 'success';
    v_message TEXT := '';
    v_count INTEGER;
    v_post_type TEXT;
    v_author_id UUID;
BEGIN
    -- Check if post exists and get essential data
    BEGIN
        SELECT post_type, user_id INTO v_post_type, v_author_id
        FROM posts
        WHERE id = p_post_id;
        
        IF NOT FOUND THEN
            v_status := 'error';
            v_message := 'Post not found';
            RETURN QUERY SELECT FALSE, 0, v_status, v_message;
            RETURN;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_status := 'error';
        v_message := 'Error checking post: ' || SQLERRM;
        RETURN QUERY SELECT FALSE, 0, v_status, v_message;
        RETURN;
    END;

    -- Check if user has already starred this post
    BEGIN
        SELECT EXISTS(
            SELECT 1 FROM user_favorites
            WHERE post_id = p_post_id AND user_id = p_user_id
        ) INTO current_star_state;
    EXCEPTION WHEN OTHERS THEN
        v_status := 'error';
        v_message := 'Error checking star state: ' || SQLERRM;
        RETURN QUERY SELECT FALSE, 0, v_status, v_message;
        RETURN;
    END;

    IF current_star_state THEN
        -- User is unstarring the post
        BEGIN
            -- Remove star from user_favorites table
            DELETE FROM user_favorites
            WHERE post_id = p_post_id AND user_id = p_user_id;
            
            -- Record how many rows were affected
            GET DIAGNOSTICS v_count = ROW_COUNT;
            IF v_count = 0 THEN
                v_message := 'No star record found to delete';
            ELSE
                v_message := 'Star record deleted successfully';
            END IF;
            
            -- Decrement star_count in posts table
            UPDATE posts
            SET star_count = GREATEST(0, COALESCE(posts.star_count, 0) - 1),
                updated_at = NOW()
            WHERE id = p_post_id;
            
            -- Get updated count
            SELECT COALESCE(posts.star_count, 0) INTO new_count
            FROM posts WHERE posts.id = p_post_id;
            
            v_message := 'Successfully unstarred post';
            RETURN QUERY SELECT FALSE, new_count, v_status, v_message;
        EXCEPTION WHEN OTHERS THEN
            v_status := 'error';
            v_message := 'Error unstarring post: ' || SQLERRM;
            RETURN QUERY SELECT current_star_state, 0, v_status, v_message;
            RETURN;
        END;
    ELSE
        -- User is starring the post
        BEGIN
            -- Add star to user_favorites table
            INSERT INTO user_favorites (user_id, post_id, created_at)
            VALUES (p_user_id, p_post_id, NOW())
            ON CONFLICT (user_id, post_id) DO NOTHING; -- Prevent duplicates
            
            -- Record how many rows were affected
            GET DIAGNOSTICS v_count = ROW_COUNT;
            IF v_count = 0 THEN
                v_message := 'No new star record inserted (possible duplicate)';
            ELSE
                v_message := 'Star record inserted successfully';
            END IF;
            
            -- Increment star_count in posts table
            UPDATE posts
            SET star_count = COALESCE(posts.star_count, 0) + 1,
                updated_at = NOW()
            WHERE id = p_post_id;
            
            -- Get updated count
            SELECT COALESCE(posts.star_count, 0) INTO new_count
            FROM posts WHERE posts.id = p_post_id;
            
            v_message := 'Successfully starred post';
            RETURN QUERY SELECT TRUE, new_count, v_status, v_message;
        EXCEPTION WHEN OTHERS THEN
            v_status := 'error';
            v_message := 'Error starring post: ' || SQLERRM;
            RETURN QUERY SELECT current_star_state, 0, v_status, v_message;
            RETURN;
        END;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return current state
        v_status := 'error';
        v_message := 'Error in toggle_post_star: ' || SQLERRM;
        
        -- Return current state as fallback
        SELECT COALESCE(posts.star_count, 0) INTO new_count
        FROM posts WHERE posts.id = p_post_id;
        
        RETURN QUERY SELECT current_star_state, new_count, v_status, v_message;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.toggle_post_star TO authenticated;

-- Add comment to explain the function
COMMENT ON FUNCTION public.toggle_post_star IS 'Toggles star/favorite status for a post. Returns the new state, star count, status and message.';