-- =====================================================
-- GROUP CHAT SYSTEM SETUP
-- =====================================================

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS public.group_messages CASCADE;
DROP TABLE IF EXISTS public.groups CASCADE;

-- =====================================================
-- GROUPS TABLE
-- =====================================================
CREATE TABLE public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT DEFAULT NULL, -- Will default to black circle with "YAP" if null
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Group settings
    is_active BOOLEAN DEFAULT true,
    max_members INTEGER DEFAULT 100,
    
    -- Members stored as JSON array of user objects
    -- Format: [{"user_id": "uuid", "role": "admin|member", "joined_at": "timestamp", "nickname": "string"}]
    members JSONB DEFAULT '[]'::jsonb NOT NULL,
    
    -- Group settings stored as JSON
    -- Format: {"allow_member_invite": true, "message_expiry_hours": 24, "encryption_enabled": true}
    settings JSONB DEFAULT '{"allow_member_invite": true, "message_expiry_hours": 24, "encryption_enabled": true}'::jsonb NOT NULL
);

-- =====================================================
-- GROUP MESSAGES TABLE
-- =====================================================
CREATE TABLE public.group_messages (
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
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Groups indexes
CREATE INDEX idx_groups_created_by ON public.groups(created_by);
CREATE INDEX idx_groups_active ON public.groups(is_active);
CREATE INDEX idx_groups_members ON public.groups USING GIN(members);

-- Group messages indexes
CREATE INDEX idx_group_messages_group_id ON public.group_messages(group_id);
CREATE INDEX idx_group_messages_sender_id ON public.group_messages(sender_id);
CREATE INDEX idx_group_messages_created_at ON public.group_messages(created_at DESC);
CREATE INDEX idx_group_messages_expires_at ON public.group_messages(expires_at);
CREATE INDEX idx_group_messages_read_by ON public.group_messages USING GIN(read_by);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on both tables
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- Groups policies
CREATE POLICY "Users can view groups they are members of" ON public.groups
    FOR SELECT USING (
        auth.uid() IN (
            SELECT (jsonb_array_elements(members)->>'user_id')::uuid
        )
    );

CREATE POLICY "Users can create groups" ON public.groups
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Group admins can update groups" ON public.groups
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT (jsonb_array_elements(members)->>'user_id')::uuid
            FROM (SELECT members) AS m
            WHERE jsonb_array_elements(members)->>'role' = 'admin'
        )
    );

-- Group messages policies
CREATE POLICY "Group members can view messages" ON public.group_messages
    FOR SELECT USING (
        auth.uid() IN (
            SELECT (jsonb_array_elements(g.members)->>'user_id')::uuid
            FROM public.groups g
            WHERE g.id = group_id
        )
    );

CREATE POLICY "Group members can send messages" ON public.group_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        auth.uid() IN (
            SELECT (jsonb_array_elements(g.members)->>'user_id')::uuid
            FROM public.groups g
            WHERE g.id = group_id
        )
    );

CREATE POLICY "Message senders can update their messages" ON public.group_messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- =====================================================
-- HELPER FUNCTIONS
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
    
    IF current_members @> jsonb_build_array(jsonb_build_object('user_id', user_uuid)) THEN
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

-- Function to get user's groups
CREATE OR REPLACE FUNCTION get_user_groups(user_uuid UUID)
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
        g.id,
        g.name,
        g.description,
        g.icon_url,
        jsonb_array_length(g.members) AS member_count,
        gm.content AS last_message_content,
        gm.created_at AS last_message_time,
        (
            SELECT COUNT(*)::INTEGER
            FROM public.group_messages gm2
            WHERE gm2.group_id = g.id
            AND gm2.expires_at > NOW()
            AND NOT (gm2.read_by ? user_uuid::text)
        ) AS unread_count
    FROM public.groups g
    LEFT JOIN LATERAL (
        SELECT content, created_at
        FROM public.group_messages
        WHERE group_id = g.id
        AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
    ) gm ON true
    WHERE g.is_active = true
    AND user_uuid IN (
        SELECT (jsonb_array_elements(g.members)->>'user_id')::uuid
    )
    ORDER BY COALESCE(gm.created_at, g.created_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STORAGE BUCKET FOR GROUP ICONS
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

-- Storage policies for group icons
CREATE POLICY "Group members can view group icons" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'group-icons' AND
        EXISTS (
            SELECT 1 FROM public.groups g
            WHERE g.icon_url LIKE '%' || name || '%'
            AND auth.uid() IN (
                SELECT (jsonb_array_elements(g.members)->>'user_id')::uuid
            )
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
