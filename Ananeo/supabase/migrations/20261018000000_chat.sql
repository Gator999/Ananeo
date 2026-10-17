-- Chat on pickup requests.
-- Messages already hang off a conversation row (see the initial schema), with participant-only
-- policies and realtime. This adds what the app needs around them: where each person has read up
-- to, and an inbox summary so the Pickups tab can show the latest message and an unread count.

-- ---------------------------------------------------------------------------
-- Read state, one row per person per conversation. Written only through mark_conversation_read.
-- ---------------------------------------------------------------------------

create table public.conversation_reads (
    conversation_id uuid not null references public.conversations (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    read_at timestamptz not null default now(),
    primary key (conversation_id, user_id)
);

alter table public.conversation_reads enable row level security;

create policy "reads own" on public.conversation_reads
    for select to authenticated
    using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Marks everything in a conversation as read for the signed-in user.
-- ---------------------------------------------------------------------------

create function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not public.is_conversation_member(p_conversation_id) then
        raise exception 'Not part of this conversation' using errcode = '42501';
    end if;

    insert into public.conversation_reads (conversation_id, user_id)
    values (p_conversation_id, (select auth.uid()))
    on conflict (conversation_id, user_id) do update set read_at = now();
end;
$$;

-- ---------------------------------------------------------------------------
-- One row per conversation the signed-in user is in that has messages: the latest message and
-- how many messages from the other person arrived after they last read it.
-- ---------------------------------------------------------------------------

create function public.my_chats()
returns table (
    conversation_id uuid,
    last_body text,
    last_sender_is_me boolean,
    last_at timestamptz,
    unread_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        c.id,
        last.body,
        last.sender_id = me.id,
        last.created_at,
        (
            select count(*)::integer from public.messages m
            where m.conversation_id = c.id
              and m.sender_id <> me.id
              and m.created_at > coalesce(r.read_at, '-infinity')
        )
    from (select (select auth.uid()) as id) me
    join public.conversations c on me.id in (c.giver_id, c.receiver_id)
    join lateral (
        select m.body, m.sender_id, m.created_at from public.messages m
        where m.conversation_id = c.id
        order by m.created_at desc, m.id desc
        limit 1
    ) last on true
    left join public.conversation_reads r on r.conversation_id = c.id and r.user_id = me.id;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. New functions are executable by everyone by default, so start from nothing.
-- ---------------------------------------------------------------------------

-- The server stamps the sender and time, so a client can't post as someone else or reorder a chat.
revoke insert on public.messages from authenticated;
grant insert (conversation_id, body) on public.messages to authenticated;

revoke all on public.conversation_reads from anon, authenticated;
grant select on public.conversation_reads to authenticated;

revoke execute on function public.mark_conversation_read(uuid) from public, anon, authenticated;
revoke execute on function public.my_chats() from public, anon, authenticated;

grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.my_chats() to authenticated;
