-- Notifications System Migration
-- This file sets up the complete notifications system including:
-- 1. Notifications table
-- 2. Device tokens table
-- 3. Notification logs for debugging
-- 4. Triggers and functions for notification management

-- Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_username TEXT,
    actor_nickname TEXT,
    actor_avatar TEXT,
    type TEXT NOT NULL, -- 'follow', 'like', 'comment', 'message'
    post_id UUID, -- Reference to post (for like/comment)
    comment_id UUID, -- Reference to comment
    message TEXT, -- Additional message content
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster lookups by user
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications (created_at DESC);

-- Add index for actor lookups
CREATE INDEX IF NOT EXISTS notifications_actor_id_idx ON public.notifications (actor_id);

-- Enable Row Level Security on notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can view only their own notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' AND policyname = 'Users can view their own notifications'
    ) THEN
        CREATE POLICY "Users can view their own notifications"
        ON public.notifications
        FOR SELECT
        USING (auth.uid() = user_id);
    END IF;
END $$;

-- Create policy: Users can update only their own notifications (e.g., mark as read)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' AND policyname = 'Users can update their own notifications'
    ) THEN
        CREATE POLICY "Users can update their own notifications"
        ON public.notifications
        FOR UPDATE
        USING (auth.uid() = user_id);
    END IF;
END $$;

-- Create device_tokens table for notification delivery
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT,
    device_details TEXT,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx ON public.device_tokens (user_id);

-- Enable RLS on device_tokens
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Allow users to manage their own device tokens
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'device_tokens' AND policyname = 'Users can manage their own device tokens'
    ) THEN
        CREATE POLICY "Users can manage their own device tokens"
        ON public.device_tokens
        FOR ALL
        USING (auth.uid() = user_id);
    END IF;
END $$;

-- Create notification_logs table for debugging
CREATE TABLE IF NOT EXISTS public.notification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE,
    event TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS notification_logs_notification_id_idx ON public.notification_logs (notification_id);

-- Enable Row Level Security on notification_logs
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

-- Create policy: Service role can manage notification logs
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notification_logs' AND policyname = 'Service role can manage notification logs'
    ) THEN
        CREATE POLICY "Service role can manage notification logs"
        ON public.notification_logs
        FOR ALL
        USING (auth.role() = 'service_role');
    END IF;
END $$;

-- Create policy: Users can view logs of their own notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notification_logs' AND policyname = 'Users can view logs of their own notifications'
    ) THEN
        CREATE POLICY "Users can view logs of their own notifications"
        ON public.notification_logs
        FOR SELECT
        USING (
            notification_id IN (
                SELECT id FROM public.notifications WHERE user_id = auth.uid()
            )
        );
    END IF;
END $$;

-- Add trigger to log notification delivery attempts
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to log notification delivery when a notification is created
DROP TRIGGER IF EXISTS trigger_log_notification_delivery ON public.notifications;
CREATE TRIGGER trigger_log_notification_delivery
AFTER INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.log_notification_delivery();

-- Function to create a follow notification
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for follow notifications (if follows table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'follows') THEN
        DROP TRIGGER IF EXISTS trigger_create_follow_notification ON public.follows;
        CREATE TRIGGER trigger_create_follow_notification
        AFTER INSERT ON public.follows
        FOR EACH ROW
        EXECUTE FUNCTION public.create_follow_notification();
    END IF;
END $$;

-- Update the device tokens table to track last activity
CREATE OR REPLACE FUNCTION public.update_device_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update device last seen
DROP TRIGGER IF EXISTS trigger_update_device_last_seen ON public.device_tokens;
CREATE TRIGGER trigger_update_device_last_seen
BEFORE UPDATE ON public.device_tokens
FOR EACH ROW
EXECUTE FUNCTION public.update_device_last_seen();

-- Create function to mark notifications as read
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to mark all notifications as read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = true
    WHERE user_id = auth.uid()
    AND is_read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;