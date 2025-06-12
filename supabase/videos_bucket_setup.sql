-- SQL script to recreate the video storage bucket and set proper RLS policies
-- ---------------------------------------------------------------------------
-- 1. Drop the old bucket if it still exists
-- NOTE: Storage buckets are rows in the "storage.buckets" table.
--       ON DELETE CASCADE will remove associated objects.

delete from storage.buckets where id = 'Video Posts';

-- 2. Create the new bucket called "videos"
--    Set "public" to false so that only signed URLs or RLS-approved users can access objects.
insert into storage.buckets (id, name, public)
values ('videos', 'videos', false)
on conflict (id) do nothing;

-- 3. Ensure RLS is enabled on the storage.objects table
alter table storage.objects enable row level security;

-- 4. Remove existing policies for this bucket (if any) to prevent duplicates
--    (This is idempotent – it’s safe to run multiple times)

-- Drop policies only if they exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE  schemaname = 'storage'
      AND  tablename  = 'objects'
      AND  policyname = 'videos_owner_full_access'
  ) THEN
    EXECUTE 'drop policy videos_owner_full_access on storage.objects';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE  schemaname = 'storage'
      AND  tablename  = 'objects'
      AND  policyname = 'public_read_videos'
  ) THEN
    EXECUTE 'drop policy public_read_videos on storage.objects';
  END IF;
END $$;

-- 5. Policy: Authenticated users can CRUD objects they own in the "videos" bucket
create policy videos_owner_full_access
on storage.objects
for all
using (
  bucket_id = 'videos' AND auth.uid() = owner
);

-- 6. (Optional) Policy: Allow public read access to video files that are marked "is_public" (custom metadata flag)
--    If you require public playback via signed URLs only, skip this block.
-- create policy public_read_videos
-- on storage.objects
-- for select
-- using (
--   bucket_id = 'videos' AND (auth.role() = 'anon' OR auth.role() = 'authenticated') AND (metadata ->> 'is_public')::boolean = true
-- );

-- 7. Grant the storage service role minimal rights to the bucket (usually handled by Supabase automatically)
--    Included here for completeness.
grant usage on schema storage to authenticated, anon;
