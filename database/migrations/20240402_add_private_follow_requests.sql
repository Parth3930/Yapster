-- Add private column to profiles table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'private'
    ) THEN
        ALTER TABLE profiles ADD COLUMN private BOOLEAN DEFAULT true;
    END IF;
END $$;

-- Create follow_requests table
CREATE TABLE IF NOT EXISTS follow_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(requester_id, receiver_id)
);

-- Add RLS policies for follow_requests
ALTER TABLE follow_requests ENABLE ROW LEVEL SECURITY;

-- Anyone can create a follow request
CREATE POLICY "Users can create follow requests" 
ON follow_requests FOR INSERT 
TO authenticated 
WITH CHECK (requester_id = auth.uid());

-- Users can see follow requests they've sent or received
CREATE POLICY "Users can view their own follow requests" 
ON follow_requests FOR SELECT 
TO authenticated 
USING (requester_id = auth.uid() OR receiver_id = auth.uid());

-- Users can only delete their own follow requests
CREATE POLICY "Users can delete follow requests they've sent or received" 
ON follow_requests FOR DELETE 
TO authenticated 
USING (requester_id = auth.uid() OR receiver_id = auth.uid());

-- Create function to send follow request
CREATE OR REPLACE FUNCTION request_follow(p_requester_id UUID, p_receiver_id UUID)
RETURNS VOID AS $$
DECLARE
    is_private BOOLEAN;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE user_id = p_receiver_id) THEN
        RAISE EXCEPTION 'User does not exist';
    END IF;
    
    -- Check if already following
    IF EXISTS (SELECT 1 FROM follows WHERE follower_id = p_requester_id AND following_id = p_receiver_id) THEN
        RAISE EXCEPTION 'Already following this user';
    END IF;
    
    -- Check if follow request already exists
    IF EXISTS (SELECT 1 FROM follow_requests WHERE requester_id = p_requester_id AND receiver_id = p_receiver_id) THEN
        RAISE EXCEPTION 'Follow request already sent';
    END IF;
    
    -- Check if the target account is private
    SELECT private INTO is_private FROM profiles WHERE user_id = p_receiver_id;
    
    -- If account is private, create follow request
    IF is_private THEN
        INSERT INTO follow_requests (requester_id, receiver_id)
        VALUES (p_requester_id, p_receiver_id);
        
        -- Create notification for follow request
        INSERT INTO notifications (
            user_id, 
            actor_id, 
            actor_username,
            actor_nickname,
            actor_avatar,
            type
        )
        SELECT 
            p_receiver_id,
            p_requester_id,
            profiles.username,
            profiles.nickname,
            profiles.avatar,
            'follow_request'
        FROM profiles
        WHERE user_id = p_requester_id;
    ELSE
        -- If account is public, follow directly
        PERFORM follow_user(p_requester_id, p_receiver_id);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to accept follow request
CREATE OR REPLACE FUNCTION accept_follow_request(p_requester_id UUID, p_receiver_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Check if request exists
    IF NOT EXISTS (SELECT 1 FROM follow_requests WHERE requester_id = p_requester_id AND receiver_id = p_receiver_id) THEN
        RAISE EXCEPTION 'Follow request not found';
    END IF;
    
    -- Follow the user
    PERFORM follow_user(p_requester_id, p_receiver_id);
    
    -- Delete the request
    DELETE FROM follow_requests WHERE requester_id = p_requester_id AND receiver_id = p_receiver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject follow request
CREATE OR REPLACE FUNCTION reject_follow_request(p_requester_id UUID, p_receiver_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Check if request exists
    IF NOT EXISTS (SELECT 1 FROM follow_requests WHERE requester_id = p_requester_id AND receiver_id = p_receiver_id) THEN
        RAISE EXCEPTION 'Follow request not found';
    END IF;
    
    -- Delete the request
    DELETE FROM follow_requests WHERE requester_id = p_requester_id AND receiver_id = p_receiver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;