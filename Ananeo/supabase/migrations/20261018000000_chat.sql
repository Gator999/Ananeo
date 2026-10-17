-- Chat on pickup requests: read markers, unread counts, and a last-message preview.
-- Messages themselves were created in the initial schema and are already published to Realtime.

-- ---------------------------------------------------------------------------
-- Clients choose only what a message or request says. Sender, timestamps, and read markers come
-- from defaults and functions, so nobody can backdate a message or mark the other side as read.
-- Clients may pick the row ID, which lets the app recognize its own message when Realtime echoes it.
-- ---------------------------------------------------------------------------

revoke insert on public.messages from authenticated;
grant insert (id, conversation_id, body) on public.messages to authenticated;

revoke insert on public.conversations from authenticated;
grant insert (id, item_id, giver_id) on public.conversations to authenticated;

-- ---------------------------------------------------------------------------
-- Read markers. A message is unread when the other person sent it after you last opened the chat.
-- ---------------------------------------------------------------------------

alter table public.conversations
    add column giver_read_at timestamptz,
    add column receiver_read_at timestamptz;

create function public.mark_conversation_read(p_conversation_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
    update public.conversations
    set giver_read_at = case when giver_id = (select auth.uid()) then now() else giver_read_at end,
        receiver_read_at = case when receiver_id = (select auth.uid()) then now() else receiver_read_at end
    where id = p_conversation_id
      and (select auth.uid()) in (giver_id, receiver_id);
$$;

-- ---------------------------------------------------------------------------
-- my_pickups gains unread counts and the latest message, and sorts by latest activity.
-- The return type changes, so the function is dropped and created again.
-- ---------------------------------------------------------------------------

drop function public.my_pickups();

create function public.my_pickups()
returns table (
    request_id uuid,
    item_id uuid,
    title text,
    category public.item_category,
    photo text,
    item_status public.item_status,
    is_giver boolean,
    other_user_id uuid,
    other_name text,
    requested_at timestamptz,
    handoff_id uuid,
    confirmed_by_me boolean,
    confirmed_by_them boolean,
    completed_at timestamptz,
    unread_count bigint,
    last_message text,
    last_message_at timestamptz,
    last_message_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        c.id,
        i.id,
        i.title,
        i.category,
        i.photos[1],
        i.status,
        c.giver_id = me.id,
        other.id,
        other.display_name,
        c.created_at,
        h.id,
        coalesce(case when c.giver_id = me.id then h.confirmed_by_giver else h.confirmed_by_receiver end, false),
        coalesce(case when c.giver_id = me.id then h.confirmed_by_receiver else h.confirmed_by_giver end, false),
        h.completed_at,
        (
            select count(*) from public.messages m
            where m.conversation_id = c.id
              and m.sender_id <> me.id
              and m.created_at > coalesce(
                  case when c.giver_id = me.id then c.giver_read_at else c.receiver_read_at end,
                  '-infinity'
              )
        ),
        lm.body,
        lm.created_at,
        lm.sender_id = me.id
    from (select (select auth.uid()) as id) me
    join public.conversations c on me.id in (c.giver_id, c.receiver_id)
    join public.items i on i.id = c.item_id
    join public.profiles other on other.id = case when c.giver_id = me.id then c.receiver_id else c.giver_id end
    left join public.handoffs h on h.item_id = c.item_id and h.receiver_id = c.receiver_id
    left join lateral (
        select m.body, m.created_at, m.sender_id from public.messages m
        where m.conversation_id = c.id
        order by m.created_at desc, m.id desc
        limit 1
    ) lm on true
    -- A block hides open requests, but not a reservation, so the giver can still cancel it.
    where (h.id is not null or not public.is_blocked(c.giver_id, c.receiver_id))
      and not (c.giver_id = me.id and h.id is null and i.status in ('removed', 'handed_off'))
    order by greatest(c.created_at, h.completed_at, lm.created_at) desc;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. New functions are executable by everyone by default, so start from nothing.
-- ---------------------------------------------------------------------------

revoke execute on function public.mark_conversation_read(uuid) from public, anon, authenticated;
revoke execute on function public.my_pickups() from public, anon, authenticated;

grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.my_pickups() to authenticated;
