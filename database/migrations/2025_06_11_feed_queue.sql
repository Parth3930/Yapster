-- Migration: create feed_queue table and supporting indexes for Yapster intelligent feed

-- 1. feed_queue stores what each user should see next. Rows live only until they are consumed.
create table if not exists public.feed_queue (
    user_id     uuid not null references public.profiles(user_id) on delete cascade,
    post_id     uuid not null references public.posts(id)    on delete cascade,
    score       numeric default 0.0,
    queued_at   timestamptz default now(),
    consumed    bool default false,
    primary key (user_id, post_id)
);

-- Composite index for fast look-up of the next batch
create index if not exists feed_queue_lookup_idx
    on public.feed_queue (user_id, consumed, score desc, queued_at desc);

-- Interaction helper index (useful when we join with interactions)
create index if not exists user_interactions_user_idx
    on public.user_interactions (user_id);

create index if not exists user_interactions_post_idx
    on public.user_interactions (post_id);

-- Enable row level security and restrict visibility to row owner
alter table public.feed_queue enable row level security;

create policy "Feed queue owners read" on public.feed_queue
    for select using (user_id = auth.uid());

create policy "Feed queue owners update" on public.feed_queue
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());
