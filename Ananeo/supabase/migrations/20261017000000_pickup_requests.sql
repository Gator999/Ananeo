-- Pickup requests, reservations, and handoff confirmation.
-- A conversation row doubles as a pickup request: the receiver opens it from a listing, and the
-- giver reserves the item for one of the people who asked. Chat messages will hang off the same row.

-- my_pickups looks conversations up from either side.
create index conversations_giver_idx on public.conversations (giver_id);
create index conversations_receiver_idx on public.conversations (receiver_id);

-- ---------------------------------------------------------------------------
-- Owners edit an item only while it is available or removed. Reserved and handed-off items change
-- only through the functions below, so a direct update can't strand a pending handoff or re-list
-- something that was already given away.
-- ---------------------------------------------------------------------------

alter policy "items update own" on public.items
    using (owner_id = (select auth.uid()) and status in ('available', 'removed'));

-- ---------------------------------------------------------------------------
-- Reserve only for someone who asked for the item.
-- ---------------------------------------------------------------------------

create or replace function public.reserve_item(p_item_id uuid, p_receiver_id uuid)
returns public.handoffs
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item public.items;
    v_handoff public.handoffs;
begin
    select * into v_item from public.items where id = p_item_id for update;
    if v_item.id is null or v_item.owner_id <> (select auth.uid()) then
        raise exception 'Only the owner can reserve this item' using errcode = '42501';
    end if;
    if v_item.status <> 'available' then
        raise exception 'Item is not available';
    end if;
    if p_receiver_id = v_item.owner_id or public.is_blocked(v_item.owner_id, p_receiver_id) then
        raise exception 'Invalid receiver';
    end if;
    if not exists (
        select 1 from public.conversations where item_id = p_item_id and receiver_id = p_receiver_id
    ) then
        raise exception 'This person has not asked for the item';
    end if;

    update public.items set status = 'reserved' where id = p_item_id;

    insert into public.handoffs (item_id, giver_id, receiver_id, est_kg)
    values (p_item_id, v_item.owner_id, p_receiver_id, v_item.est_kg)
    on conflict (item_id) do update
        set receiver_id = excluded.receiver_id,
            confirmed_by_giver = false,
            confirmed_by_receiver = false,
            completed_at = null
    returning * into v_handoff;

    return v_handoff;
end;
$$;

-- ---------------------------------------------------------------------------
-- The receiver withdraws a request. If the item was reserved for them, it becomes available again.
-- ---------------------------------------------------------------------------

create function public.withdraw_request(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_handoff public.handoffs;
begin
    -- Lock the handoff so a confirmation from the giver can't land halfway through.
    select * into v_handoff from public.handoffs
    where item_id = p_item_id and receiver_id = v_uid
    for update;

    if v_handoff.completed_at is not null then
        raise exception 'This pickup is already complete';
    end if;
    if v_handoff.id is not null then
        delete from public.handoffs where id = v_handoff.id;
        update public.items set status = 'available' where id = p_item_id and status = 'reserved';
    end if;

    delete from public.conversations where item_id = p_item_id and receiver_id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Every request the signed-in user is part of, from either side, with the handoff for that pair.
-- Receivers keep seeing a request after the item is given to someone else or removed, so they
-- can tell what happened. Givers stop seeing requests on items they removed or gave to someone else.
-- ---------------------------------------------------------------------------

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
    completed_at timestamptz
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
        h.completed_at
    from (select (select auth.uid()) as id) me
    join public.conversations c on me.id in (c.giver_id, c.receiver_id)
    join public.items i on i.id = c.item_id
    join public.profiles other on other.id = case when c.giver_id = me.id then c.receiver_id else c.giver_id end
    left join public.handoffs h on h.item_id = c.item_id and h.receiver_id = c.receiver_id
    -- A block hides open requests, but not a reservation, so the giver can still cancel it.
    where (h.id is not null or not public.is_blocked(c.giver_id, c.receiver_id))
      and not (c.giver_id = me.id and h.id is null and i.status in ('removed', 'handed_off'))
    order by coalesce(h.completed_at, c.created_at) desc;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. New functions are executable by everyone by default, so start from nothing.
-- ---------------------------------------------------------------------------

revoke execute on function public.withdraw_request(uuid) from public, anon, authenticated;
revoke execute on function public.my_pickups() from public, anon, authenticated;

grant execute on function public.withdraw_request(uuid) to authenticated;
grant execute on function public.my_pickups() to authenticated;
