-- Fix all "Function Search Path Mutable" errors by adding SET search_path = '' to all functions
-- This migration adds the required search_path parameter to all existing functions

-- Fix log_notification_delivery function
CREATE OR REPLACE FUNCTION public.log_notification_delivery()
RETURNS TRIGGER AS $$
DECLARE
    token_record RECORD;
BEGIN
    -- Get device tokens for the user
    FOR token_record IN 
        SELECT token 
        FROM public.device_tokens 
        WHERE user_id = NEW.user_id
    LOOP
        -- Log the notification delivery attempt
        INSERT INTO public.notification_logs (
            notification_id, 
            event, 
            details
        ) VALUES (
            NEW.id, 
            'delivery_attempt', 
            jsonb_build_object(
                'token', token_record.token,
                'notification_type', NEW.type,
                'actor_id', NEW.actor_id
            )
        );
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Fix create_follow_notification function (renamed from create_notification)
CREATE OR REPLACE FUNCTION public.create_follow_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new follow is created, create a notification for the followed user
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type
    )
    SELECT 
        NEW.followed_id,
        NEW.follower_id,
        u.username,
        u.nickname,
        u.avatar_url,
        'follow'
    FROM auth.users u
    WHERE u.id = NEW.follower_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Fix update_device_last_seen function
CREATE OR REPLACE FUNCTION public.update_device_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = '';

-- Fix mark_notifications_as_read function
CREATE OR REPLACE FUNCTION public.mark_notifications_as_read(notification_ids UUID[])
RETURNS SETOF UUID AS $$
BEGIN
    RETURN QUERY
    UPDATE public.notifications
    SET is_read = true
    WHERE id = ANY(notification_ids)
    AND user_id = auth.uid()
    RETURNING id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Fix mark_all_notifications_as_read function
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = true
    WHERE user_id = auth.uid()
    AND is_read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_user_post_like_state function
CREATE OR REPLACE FUNCTION public.get_user_post_like_state(p_post_id UUID, p_user_id UUID)
RETURNS TABLE(is_liked BOOLEAN, likes_count INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXISTS(SELECT 1 FROM public.post_likes WHERE post_id = p_post_id AND user_id = p_user_id) as is_liked,
        COALESCE((SELECT posts.likes_count FROM public.posts WHERE id = p_post_id), 0) as likes_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing toggle_post_like function
CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID, p_user_id UUID)
RETURNS TABLE(is_liked BOOLEAN, likes_count INTEGER) AS $$
DECLARE
    like_exists BOOLEAN;
    new_count INTEGER;
BEGIN
    -- Check if like exists
    SELECT EXISTS(SELECT 1 FROM public.post_likes WHERE post_id = p_post_id AND user_id = p_user_id) INTO like_exists;
    
    IF like_exists THEN
        -- Remove like
        DELETE FROM public.post_likes WHERE post_id = p_post_id AND user_id = p_user_id;
        -- Decrement likes count
        UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = p_post_id;
    ELSE
        -- Add like
        INSERT INTO public.post_likes (post_id, user_id, created_at) VALUES (p_post_id, p_user_id, NOW());
        -- Increment likes count
        UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = p_post_id;
    END IF;
    
    -- Get updated count
    SELECT posts.likes_count INTO new_count FROM public.posts WHERE id = p_post_id;
    
    RETURN QUERY SELECT NOT like_exists as is_liked, COALESCE(new_count, 0) as likes_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing increment_post_engagement function
CREATE OR REPLACE FUNCTION public.increment_post_engagement(post_id UUID, column_name TEXT, increment_by INTEGER)
RETURNS VOID AS $$
BEGIN
    CASE column_name
        WHEN 'likes_count' THEN
            UPDATE public.posts SET likes_count = likes_count + increment_by WHERE id = post_id;
        WHEN 'comments_count' THEN
            UPDATE public.posts SET comments_count = comments_count + increment_by WHERE id = post_id;
        WHEN 'views_count' THEN
            UPDATE public.posts SET views_count = views_count + increment_by WHERE id = post_id;
        WHEN 'shares_count' THEN
            UPDATE public.posts SET shares_count = shares_count + increment_by WHERE id = post_id;
        ELSE
            RAISE EXCEPTION 'Invalid column name: %', column_name;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing increment_post_engagement_simple function
CREATE OR REPLACE FUNCTION public.increment_post_engagement_simple(p_post_id UUID, p_column TEXT, p_increment INTEGER)
RETURNS VOID AS $$
BEGIN
    CASE p_column
        WHEN 'likes_count' THEN
            UPDATE public.posts SET likes_count = GREATEST(0, likes_count + p_increment) WHERE id = p_post_id;
        WHEN 'comments_count' THEN
            UPDATE public.posts SET comments_count = GREATEST(0, comments_count + p_increment) WHERE id = p_post_id;
        WHEN 'views_count' THEN
            UPDATE public.posts SET views_count = GREATEST(0, views_count + p_increment) WHERE id = p_post_id;
        WHEN 'shares_count' THEN
            UPDATE public.posts SET shares_count = GREATEST(0, shares_count + p_increment) WHERE id = p_post_id;
        ELSE
            RAISE EXCEPTION 'Invalid column name: %', p_column;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing search_following_users function
CREATE OR REPLACE FUNCTION public.search_following_users(user_uuid UUID, search_query TEXT)
RETURNS TABLE(id UUID, username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.nickname,
        u.avatar_url,
        u.google_avatar
    FROM auth.users u
    INNER JOIN public.follows f ON f.followed_id = u.id
    WHERE f.follower_id = user_uuid
    AND (
        LOWER(u.username) LIKE LOWER('%' || search_query || '%') OR
        LOWER(u.nickname) LIKE LOWER('%' || search_query || '%')
    )
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_posts_feed function
CREATE OR REPLACE FUNCTION public.get_posts_feed(p_user_id UUID, p_limit INTEGER, p_offset INTEGER)
RETURNS TABLE(
    id UUID, user_id UUID, content TEXT, image_urls TEXT[], created_at TIMESTAMPTZ,
    likes_count INTEGER, comments_count INTEGER, views_count INTEGER, shares_count INTEGER,
    username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id, p.user_id, p.content, p.image_urls, p.created_at,
        p.likes_count, p.comments_count, p.views_count, p.shares_count,
        u.username, u.nickname, u.avatar_url, u.google_avatar
    FROM public.posts p
    INNER JOIN auth.users u ON p.user_id = u.id
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_intelligent_posts_feed function
CREATE OR REPLACE FUNCTION public.get_intelligent_posts_feed(p_user_id UUID, p_limit INTEGER, p_offset INTEGER)
RETURNS TABLE(
    id UUID, user_id UUID, content TEXT, image_urls TEXT[], created_at TIMESTAMPTZ,
    likes_count INTEGER, comments_count INTEGER, views_count INTEGER, shares_count INTEGER,
    username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT
) AS $$
BEGIN
    -- For now, return the same as regular feed - can be enhanced later with ML algorithms
    RETURN QUERY
    SELECT * FROM public.get_posts_feed(p_user_id, p_limit, p_offset);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing fetch_users_recent_chats function
CREATE OR REPLACE FUNCTION public.fetch_users_recent_chats(user_uuid UUID)
RETURNS TABLE(
    id UUID, username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT,
    last_message TEXT, last_message_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, u.username, u.nickname, u.avatar_url, u.google_avatar,
        ''::TEXT as last_message, NOW() as last_message_time
    FROM auth.users u
    WHERE u.id != user_uuid
    ORDER BY u.username
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing fetch_users_recent_chats_enhanced function
CREATE OR REPLACE FUNCTION public.fetch_users_recent_chats_enhanced(user_uuid UUID)
RETURNS TABLE(
    id UUID, username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT,
    last_message TEXT, last_message_time TIMESTAMPTZ, unread_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, u.username, u.nickname, u.avatar_url, u.google_avatar,
        ''::TEXT as last_message, NOW() as last_message_time, 0 as unread_count
    FROM auth.users u
    WHERE u.id != user_uuid
    ORDER BY u.username
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_followers function
CREATE OR REPLACE FUNCTION public.get_followers(p_user_id UUID)
RETURNS TABLE(id UUID, username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, u.username, u.nickname, u.avatar_url, u.google_avatar
    FROM auth.users u
    INNER JOIN public.follows f ON f.follower_id = u.id
    WHERE f.followed_id = p_user_id
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_following function
CREATE OR REPLACE FUNCTION public.get_following(p_user_id UUID)
RETURNS TABLE(id UUID, username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, u.username, u.nickname, u.avatar_url, u.google_avatar
    FROM auth.users u
    INNER JOIN public.follows f ON f.followed_id = u.id
    WHERE f.follower_id = p_user_id
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing follow_user function
CREATE OR REPLACE FUNCTION public.follow_user(p_follower_id UUID, p_following_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.follows (follower_id, followed_id, created_at)
    VALUES (p_follower_id, p_following_id, NOW())
    ON CONFLICT (follower_id, followed_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing update_follower_count function
CREATE OR REPLACE FUNCTION public.update_follower_count(f_count INTEGER, t_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE auth.users SET follower_count = f_count WHERE id = t_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Alternative version of update_follower_count
CREATE OR REPLACE FUNCTION public.update_follower_count(user_id_param UUID, new_count INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE auth.users SET follower_count = new_count WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing handle_follow_notification function
CREATE OR REPLACE FUNCTION public.handle_follow_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Same as create_follow_notification but with different name for compatibility
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type
    )
    SELECT
        NEW.followed_id,
        NEW.follower_id,
        u.username,
        u.nickname,
        u.avatar_url,
        'follow'
    FROM auth.users u
    WHERE u.id = NEW.follower_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing handle_like_notification function
CREATE OR REPLACE FUNCTION public.handle_like_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Create notification when someone likes a post
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type,
        post_id
    )
    SELECT
        p.user_id,
        NEW.user_id,
        u.username,
        u.nickname,
        u.avatar_url,
        'like',
        NEW.post_id
    FROM public.posts p
    INNER JOIN auth.users u ON u.id = NEW.user_id
    WHERE p.id = NEW.post_id
    AND p.user_id != NEW.user_id; -- Don't notify if user likes their own post

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing handle_comment_notification function
CREATE OR REPLACE FUNCTION public.handle_comment_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Create notification when someone comments on a post
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type,
        post_id,
        comment_id,
        message
    )
    SELECT
        p.user_id,
        NEW.user_id,
        u.username,
        u.nickname,
        u.avatar_url,
        'comment',
        NEW.post_id,
        NEW.id,
        LEFT(NEW.content, 100) -- First 100 chars of comment
    FROM public.posts p
    INNER JOIN auth.users u ON u.id = NEW.user_id
    WHERE p.id = NEW.post_id
    AND p.user_id != NEW.user_id; -- Don't notify if user comments on their own post

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing handle_message_notification function
CREATE OR REPLACE FUNCTION public.handle_message_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Create notification when someone sends a message
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type,
        message
    )
    SELECT
        NEW.receiver_id,
        NEW.sender_id,
        u.username,
        u.nickname,
        u.avatar_url,
        'message',
        LEFT(NEW.content, 100) -- First 100 chars of message
    FROM auth.users u
    WHERE u.id = NEW.sender_id
    AND NEW.receiver_id != NEW.sender_id; -- Don't notify if user messages themselves

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing increment_comment_count function
CREATE OR REPLACE FUNCTION public.increment_comment_count(p_post_id UUID, p_increment INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE public.posts
    SET comments_count = GREATEST(0, comments_count + p_increment)
    WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing get_intelligent_posts_feed_fallback function
CREATE OR REPLACE FUNCTION public.get_intelligent_posts_feed_fallback(p_user_id UUID, p_limit INTEGER, p_offset INTEGER)
RETURNS TABLE(
    id UUID, user_id UUID, content TEXT, image_urls TEXT[], created_at TIMESTAMPTZ,
    likes_count INTEGER, comments_count INTEGER, views_count INTEGER, shares_count INTEGER,
    username TEXT, nickname TEXT, avatar_url TEXT, google_avatar TEXT
) AS $$
BEGIN
    -- Fallback function that returns posts ordered by engagement
    RETURN QUERY
    SELECT
        p.id, p.user_id, p.content, p.image_urls, p.created_at,
        p.likes_count, p.comments_count, p.views_count, p.shares_count,
        u.username, u.nickname, u.avatar_url, u.google_avatar
    FROM public.posts p
    INNER JOIN auth.users u ON p.user_id = u.id
    ORDER BY (p.likes_count + p.comments_count + p.shares_count) DESC, p.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing notify_profile_changes function
CREATE OR REPLACE FUNCTION public.notify_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- This function can be used to notify followers when a user updates their profile
    -- For now, it's a placeholder that just returns the new record
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Create missing update_updated_at_column function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = '';

-- Create missing create_notification function (generic version)
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_actor_id UUID,
    p_type TEXT,
    p_post_id UUID DEFAULT NULL,
    p_comment_id UUID DEFAULT NULL,
    p_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
    actor_data RECORD;
BEGIN
    -- Get actor information
    SELECT username, nickname, avatar_url INTO actor_data
    FROM auth.users WHERE id = p_actor_id;

    -- Insert notification
    INSERT INTO public.notifications (
        user_id,
        actor_id,
        actor_username,
        actor_nickname,
        actor_avatar,
        type,
        post_id,
        comment_id,
        message
    ) VALUES (
        p_user_id,
        p_actor_id,
        actor_data.username,
        actor_data.nickname,
        actor_data.avatar_url,
        p_type,
        p_post_id,
        p_comment_id,
        p_message
    ) RETURNING id INTO notification_id;

    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
