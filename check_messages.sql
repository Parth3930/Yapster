-- Check if there are any actually expired messages
SELECT COUNT(*) as expired_count 
FROM public.messages 
WHERE expires_at < NOW();

-- Show some example expiration dates to confirm
SELECT message_id, expires_at, NOW() as current_time,
       CASE WHEN expires_at < NOW() THEN 'EXPIRED' ELSE 'NOT EXPIRED' END as status
FROM public.messages 
ORDER BY expires_at
LIMIT 10;

-- To test the function with a specific message, try:
-- This will work only if you have permission to update the messages table
-- UPDATE public.messages 
-- SET expires_at = NOW() - INTERVAL '1 minute'
-- WHERE message_id = [some_id];
-- Then run: SELECT public.cleanup_expired_messages();