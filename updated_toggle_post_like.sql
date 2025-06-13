DECLARE
    current_like_state BOOLEAN := FALSE;
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

    -- Check if user has already liked this post
    BEGIN
        SELECT EXISTS(
            SELECT 1 FROM post_likes
            WHERE post_id = p_post_id AND user_id = p_user_id
        ) INTO current_like_state;
    EXCEPTION WHEN OTHERS THEN
        v_status := 'error';
        v_message := 'Error checking like state: ' || SQLERRM;
        RETURN QUERY SELECT FALSE, 0, v_status, v_message;
        RETURN;
    END;

    IF current_like_state THEN
        -- User is unliking the post
        BEGIN
            -- Remove like from post_likes table
            DELETE FROM post_likes
            WHERE post_id = p_post_id AND user_id = p_user_id;
            
            -- Record how many rows were affected
            GET DIAGNOSTICS v_count = ROW_COUNT;
            IF v_count = 0 THEN
                v_message := 'No like record found to delete';
            ELSE
                v_message := 'Like record deleted successfully';
            END IF;
            
            -- Decrement likes_count in posts table
            UPDATE posts
            SET likes_count = GREATEST(0, COALESCE(likes_count, 0) - 1),
                updated_at = NOW()
            WHERE id = p_post_id;
            
            -- Get updated count
            SELECT COALESCE(likes_count, 0) INTO new_count
            FROM posts WHERE id = p_post_id;
            
            v_message := 'Successfully unliked post';
            RETURN QUERY SELECT FALSE, new_count, v_status, v_message;
        EXCEPTION WHEN OTHERS THEN
            v_status := 'error';
            v_message := 'Error unliking post: ' || SQLERRM;
            RETURN QUERY SELECT current_like_state, 0, v_status, v_message;
            RETURN;
        END;
    ELSE
        -- User is liking the post
        BEGIN
            -- Add like to post_likes table
            INSERT INTO post_likes (user_id, post_id, created_at)
            VALUES (p_user_id, p_post_id, NOW())
            ON CONFLICT (user_id, post_id) DO NOTHING; -- Prevent duplicates
            
            -- Record how many rows were affected
            GET DIAGNOSTICS v_count = ROW_COUNT;
            IF v_count = 0 THEN
                v_message := 'No new like record inserted (possible duplicate)';
            ELSE
                v_message := 'Like record inserted successfully';
            END IF;
            
            -- Increment likes_count in posts table
            UPDATE posts
            SET likes_count = COALESCE(likes_count, 0) + 1,
                updated_at = NOW()
            WHERE id = p_post_id;
            
            -- Get updated count
            SELECT COALESCE(likes_count, 0) INTO new_count
            FROM posts WHERE id = p_post_id;
            
            v_message := 'Successfully liked post';
            RETURN QUERY SELECT TRUE, new_count, v_status, v_message;
        EXCEPTION WHEN OTHERS THEN
            v_status := 'error';
            v_message := 'Error liking post: ' || SQLERRM;
            RETURN QUERY SELECT current_like_state, 0, v_status, v_message;
            RETURN;
        END;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return current state
        v_status := 'error';
        v_message := 'Error in toggle_post_like: ' || SQLERRM;
        
        -- Return current state as fallback
        SELECT COALESCE(likes_count, 0) INTO new_count
        FROM posts WHERE id = p_post_id;
        
        RETURN QUERY SELECT current_like_state, new_count, v_status, v_message;
END;