-- Function to delete expired messages and their associated files
CREATE OR REPLACE FUNCTION public.cleanup_expired_messages()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    message_record RECORD;
    content_text TEXT;
    storage_path TEXT;
    bucket_id TEXT := 'chat-media';
    file_urls TEXT[];
    url TEXT;
    deleted_count INTEGER := 0;
BEGIN
    -- First collect all expired messages that need processing
    FOR message_record IN 
        SELECT message_id, content 
        FROM public.messages 
        WHERE expires_at < NOW()
        FOR UPDATE -- Lock rows to prevent concurrent modification
    LOOP
        -- Check if content contains file URLs
        content_text := message_record.content;
        
        -- Extract URLs from content (assuming they follow a pattern like storage/v1/object/...)
        -- This regex pattern might need adjustment based on your actual URL format
        SELECT ARRAY(
            SELECT unnest(regexp_matches(content_text, 'storage/v1/object/[^"'')\s]+', 'g'))
        ) INTO file_urls;
        
        -- Delete each file from storage
        IF array_length(file_urls, 1) > 0 THEN
            FOREACH url IN ARRAY file_urls
            LOOP
                -- Extract the path from URL
                storage_path := substring(url from 'storage/v1/object/(.+)');
                
                -- Use Supabase storage API to delete the file
                PERFORM storage.delete_object(bucket_id, storage_path);
            END LOOP;
        END IF;
        
        -- Delete this specific message
        DELETE FROM public.messages WHERE message_id = message_record.message_id;
        GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;
    END LOOP;
    
    -- As a safeguard, also delete any other expired messages that might have been missed
    DELETE FROM public.messages WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;
    
    RETURN deleted_count;
    
    EXCEPTION WHEN OTHERS THEN
        -- Just raise the error without logging
        RAISE;
END;
$$;

-- To manually run the function for testing:
-- SELECT public.cleanup_expired_messages();

/*
IMPORTANT: SCHEDULING INSTRUCTIONS

Since the pg_cron extension requires superuser privileges in Supabase, you'll need to:

1. Contact Supabase support to schedule this function, providing them with:
   - Function name: public.cleanup_expired_messages
   - Desired schedule: hourly (or your preferred frequency)

2. Alternatively, if you have access to the Supabase dashboard SQL editor with admin privileges:
   
   -- Enable pg_cron if not already enabled (requires admin privileges)
   CREATE EXTENSION IF NOT EXISTS pg_cron;
   
   -- Schedule the job to run hourly
   SELECT cron.schedule(
       'cleanup-expired-messages',
       '0 * * * *',
       'SELECT public.cleanup_expired_messages()'
   );
   
   -- To check scheduled jobs:
   -- SELECT * FROM cron.job;
*/