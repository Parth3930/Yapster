-- Fix the enhanced function to use correct column names
create or replace function fetch_users_recent_chats_enhanced(user_uuid uuid)
returns json as $$
declare
    result json;
begin
    with user_chats as (
        select distinct c.chat_id
        from chats c
        where (c.user_one_id = user_uuid or c.user_two_id = user_uuid)
    ),
    latest_messages as (
        select 
            uc.chat_id,
            (
                select row_to_json(lm) 
                from get_latest_chat_message(uc.chat_id) lm
                limit 1
            ) as last_message
        from user_chats uc
    ),
    full_chat_data as (
        select 
            c.chat_id,
            c.user_one_id,
            c.user_two_id,
            p1.username as user_one_username,
            p1.avatar as user_one_avatar,
            p1.google_avatar as user_one_google_avatar,
            p2.username as user_two_username,
            p2.avatar as user_two_avatar,
            p2.google_avatar as user_two_google_avatar,
            lm.last_message,
            case 
                when lm.last_message->>'sender_id' = user_uuid::text then true 
                else false 
            end as is_sender,
            (
                select count(*) 
                from messages m 
                where m.chat_id = c.chat_id 
                and m.is_read = false 
                and m.sender_id != user_uuid 
                and m.expires_at > now()
            ) as unread_count,
            coalesce(
                (lm.last_message->>'created_at')::timestamptz, 
                c.created_at
            ) as last_message_time
        from chats c
        join profiles p1 on c.user_one_id = p1.user_id
        join profiles p2 on c.user_two_id = p2.user_id
        left join latest_messages lm on c.chat_id = lm.chat_id
        where (c.user_one_id = user_uuid or c.user_two_id = user_uuid)
    )
    select json_agg(
        json_build_object(
            'chat_id', chat_id,
            'user_one_id', user_one_id,
            'user_two_id', user_two_id,
            'user_one_username', user_one_username,
            'user_one_avatar', user_one_avatar,
            'user_one_google_avatar', user_one_google_avatar,
            'user_two_username', user_two_username,
            'user_two_avatar', user_two_avatar,
            'user_two_google_avatar', user_two_google_avatar,
            'last_message', (last_message->>'content'),
            'last_message_type', (last_message->>'message_type'),
            'last_sender_id', (last_message->>'sender_id'),
            'is_sender', is_sender,
            'unread_count', unread_count,
            'last_message_time', last_message_time
        )
    ) into result
    from full_chat_data
    order by last_message_time desc;

    return coalesce(result, '[]'::json);
end;
$$ language plpgsql security definer;
