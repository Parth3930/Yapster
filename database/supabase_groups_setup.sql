-- =====================================================
-- YAPSTER GROUP CHAT SYSTEM - SUPABASE SETUP
-- =====================================================
-- Run this script in your Supabase SQL Editor to set up group chat functionality

-- =====================================================
-- 1. CREATE GROUPS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT DEFAULT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Group settings
    is_active BOOLEAN DEFAULT true,
    max_members INTEGER DEFAULT 100,
    
    -- Members stored as JSON array
    -- Format: [{"user_id": "uuid", "role": "admin|member", "joined_at": "timestamp", "nickname": "string"}]
    members JSONB DEFAULT '[]'::jsonb NOT NULL,
    
    -- Group settings stored as JSON
    -- Format: {"allow_member_invite": true, "message_expiry_hours": 24, "encryption_enabled": true}
    settings JSONB DEFAULT '{"allow_member_invite": true, "message_expiry_hours": 24, "encryption_enabled": true}'::jsonb NOT NULL
);

-- =====================================================
-- 2. CREATE GROUP MESSAGES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.group_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'audio', 'shared_post')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    
    -- Message status
    is_encrypted BOOLEAN DEFAULT true,
    is_edited BOOLEAN DEFAULT false,
    edited_at TIMESTAMP WITH TIME ZONE,
    
    -- Read status for each member (JSON object)
    -- Format: {"user_id_1": "timestamp", "user_id_2": "timestamp"}
    read_by JSONB DEFAULT '{}'::jsonb NOT NULL
);

-- =====================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Groups indexes
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON public.groups(created_by);
CREATE INDEX IF NOT EXISTS idx_groups_active ON public.groups(is_active);
CREATE INDEX IF NOT EXISTS idx_groups_members ON public.groups USING GIN(members);
CREATE INDEX IF NOT EXISTS idx_groups_created_at ON public.groups(created_at DESC);

-- Group messages indexes
CREATE INDEX IF NOT EXISTS idx_group_messages_group_id ON public.group_messages(group_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_sender_id ON public.group_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_created_at ON public.group_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_messages_expires_at ON public.group_messages(expires_at);
CREATE INDEX IF NOT EXISTS idx_group_messages_read_by ON public.group_messages USING GIN(read_by);

-- =====================================================
-- 4. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 5. CREATE RLS POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view groups they are members of" ON public.groups;
DROP POLICY IF EXISTS "Users can create groups" ON public.groups;
DROP POLICY IF EXISTS "Group admins can update groups" ON public.groups;
DROP POLICY IF EXISTS "Group members can view messages" ON public.group_messages;
DROP POLICY IF EXISTS "Group members can send messages" ON public.group_messages;
DROP POLICY IF EXISTS "Message senders can update their messages" ON public.group_messages;

-- Groups policies
CREATE POLICY "Users can view groups they are members of" ON public.groups
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM jsonb_array_elements(members) AS member
            WHERE (member->>'user_id')::uuid = auth.uid()
        )
    );

CREATE POLICY "Users can create groups" ON public.groups
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Group admins can update groups" ON public.groups
    FOR UPDATE USING (
        EXISTS (
            SELECT 1
            FROM jsonb_array_elements(members) AS member
            WHERE (member->>'user_id')::uuid = auth.uid()
            AND member->>'role' = 'admin'
        )
    );

-- Group messages policies
CREATE POLICY "Group members can view messages" ON public.group_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.groups g, jsonb_array_elements(g.members) AS member
            WHERE g.id = group_id
            AND (member->>'user_id')::uuid = auth.uid()
        )
    );

CREATE POLICY "Group members can send messages" ON public.group_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1
            FROM public.groups g, jsonb_array_elements(g.members) AS member
            WHERE g.id = group_id
            AND (member->>'user_id')::uuid = auth.uid()
        )
    );

CREATE POLICY "Message senders can update their messages" ON public.group_messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- =====================================================
-- 6. CREATE HELPER FUNCTIONS
-- =====================================================

-- Function to add a member to a group
CREATE OR REPLACE FUNCTION add_group_member(
    group_uuid UUID,
    user_uuid UUID,
    user_role TEXT DEFAULT 'member',
    user_nickname TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    new_member JSONB;
    current_members JSONB;
BEGIN
    -- Check if user is already a member
    SELECT members INTO current_members FROM public.groups WHERE id = group_uuid;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(current_members) AS member
        WHERE (member->>'user_id')::uuid = user_uuid
    ) THEN
        RETURN FALSE; -- User already a member
    END IF;
    
    -- Create new member object
    new_member := jsonb_build_object(
        'user_id', user_uuid,
        'role', user_role,
        'joined_at', NOW(),
        'nickname', COALESCE(user_nickname, '')
    );
    
    -- Add member to group
    UPDATE public.groups 
    SET 
        members = members || jsonb_build_array(new_member),
        updated_at = NOW()
    WHERE id = group_uuid;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove a member from a group
CREATE OR REPLACE FUNCTION remove_group_member(
    group_uuid UUID,
    user_uuid UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.groups 
    SET 
        members = (
            SELECT jsonb_agg(member)
            FROM jsonb_array_elements(members) AS member
            WHERE (member->>'user_id')::uuid != user_uuid
        ),
        updated_at = NOW()
    WHERE id = group_uuid;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's groups with latest message info
-- Drop existing function first to avoid parameter name conflicts
DROP FUNCTION IF EXISTS get_user_groups(UUID);

CREATE FUNCTION get_user_groups(input_user_uuid UUID)
RETURNS TABLE(
    group_id UUID,
    group_name VARCHAR(100),
    group_description TEXT,
    group_icon_url TEXT,
    member_count INTEGER,
    last_message_content TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE,
    unread_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        grp.id,
        grp.name,
        grp.description,
        grp.icon_url,
        jsonb_array_length(grp.members),
        latest_msg.content,
        latest_msg.created_at,
        (
            SELECT COUNT(*)::INTEGER
            FROM public.group_messages unread_msgs
            WHERE unread_msgs.group_id = grp.id
            AND unread_msgs.expires_at > NOW()
            AND NOT (unread_msgs.read_by ? input_user_uuid::text)
        )::INTEGER
    FROM public.groups grp
    LEFT JOIN LATERAL (
        SELECT msg.content, msg.created_at
        FROM public.group_messages msg
        WHERE msg.group_id = grp.id
        AND msg.expires_at > NOW()
        ORDER BY msg.created_at DESC
        LIMIT 1
    ) latest_msg ON true
    WHERE grp.is_active = true
    AND EXISTS (
        SELECT 1
        FROM jsonb_array_elements(grp.members) AS member
        WHERE (member->>'user_id')::uuid = input_user_uuid
    )
    ORDER BY COALESCE(latest_msg.created_at, grp.created_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. CREATE STORAGE BUCKET FOR GROUP ICONS
-- =====================================================

-- Create group-icons storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'group-icons',
    'group-icons',
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =====================================================
-- 8. CREATE STORAGE POLICIES FOR GROUP ICONS
-- =====================================================

-- Drop existing storage policies
DROP POLICY IF EXISTS "Group members can view group icons" ON storage.objects;
DROP POLICY IF EXISTS "Group admins can upload group icons" ON storage.objects;
DROP POLICY IF EXISTS "Group admins can update group icons" ON storage.objects;
DROP POLICY IF EXISTS "Group admins can delete group icons" ON storage.objects;

-- Storage policies for group icons
CREATE POLICY "Group members can view group icons" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'group-icons' AND
        EXISTS (
            SELECT 1
            FROM public.groups g, jsonb_array_elements(g.members) AS member
            WHERE g.icon_url LIKE '%' || name || '%'
            AND (member->>'user_id')::uuid = auth.uid()
        )
    );

CREATE POLICY "Group admins can upload group icons" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'group-icons' AND
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Group admins can update group icons" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'group-icons' AND
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Group admins can delete group icons" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'group-icons' AND
        auth.uid() IS NOT NULL
    );

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================
-- Your group chat system is now ready to use.
-- 
-- Next steps:
-- 1. Test group creation from the app
-- 2. Test group messaging
-- 3. Test post sharing to groups
-- 
-- Default group icon will be a black circle with "YAP" text
-- Users can upload custom group icons later
-- =====================================================
