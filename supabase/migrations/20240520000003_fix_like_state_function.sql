-- Create function to get user's like state for a post
-- This should match the same logic used by toggle_post_like
CREATE OR REPLACE FUNCTION get_user_post_like_state(p_post_id uuid, p_user_id uuid)
RETURNS TABLE (
    is_liked boolean,
    likes_count integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN pl.id IS NOT NULL THEN true 
            ELSE false 
        END as is_liked,
        COALESCE(p.likes_count, 0) as likes_count
    FROM posts p
    LEFT JOIN post_likes pl ON pl.post_id = p.id AND pl.user_id = p_user_id
    WHERE p.id = p_post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
