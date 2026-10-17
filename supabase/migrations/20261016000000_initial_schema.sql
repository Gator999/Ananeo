-- Ananeo initial schema
-- Every table has Row Level Security on. Writes that need cross-row rules go through
-- security definer functions so clients cannot bypass them.

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.item_category as enum ('furniture', 'clothing', 'electronics', 'tools', 'books', 'household', 'materials', 'other');
create type public.item_condition as enum ('like_new', 'good', 'worn', 'needs_repair', 'for_parts');
create type public.item_mode as enum ('give', 'swap', 'parts');
create type public.item_status as enum ('available', 'reserved', 'handed_off', 'removed');
create type public.swap_status as enum ('pending', 'accepted', 'declined', 'withdrawn');
create type public.place_kind as enum ('donation', 'repair', 'ewaste', 'textile');
create type public.report_target as enum ('item', 'user', 'message');
create type public.report_status as enum ('open', 'actioned', 'dismissed');

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null default 'Neighbor' check (char_length(display_name) between 1 and 50),
    avatar_url text,
    home_area extensions.geography(point, 4326),
    created_at timestamptz not null default now()
);

-- Create a profile row for every new auth user.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, display_name)
    values (
        new.id,
        coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Neighbor')
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Blocks (defined early because other policies depend on it)
-- ---------------------------------------------------------------------------

create table public.blocks (
    blocker_id uuid not null references public.profiles (id) on delete cascade,
    blocked_id uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

-- True when either user has blocked the other.
create function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.blocks
        where (blocker_id = a and blocked_id = b)
           or (blocker_id = b and blocked_id = a)
    );
$$;

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

create table public.items (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    title text not null check (char_length(title) between 1 and 80),
    details text not null default '' check (char_length(details) <= 2000),
    category public.item_category not null,
    condition public.item_condition not null default 'good',
    mode public.item_mode not null default 'give',
    status public.item_status not null default 'available',
    wants text check (char_length(wants) <= 200),
    -- Stored already fuzzed by trigger. The exact point is never persisted.
    location extensions.geography(point, 4326) not null,
    est_kg numeric(7, 2) check (est_kg > 0),
    photos text[] not null default '{}' check (cardinality(photos) <= 5),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index items_location_idx on public.items using gist (location);
create index items_status_created_idx on public.items (status, created_at desc);
create index items_owner_idx on public.items (owner_id);

-- Default weight estimate per category, in kilograms.
create function public.default_kg(c public.item_category)
returns numeric
language sql
immutable
as $$
    select case c
        when 'furniture' then 25
        when 'clothing' then 0.5
        when 'electronics' then 3
        when 'tools' then 2
        when 'books' then 0.8
        when 'household' then 1.5
        when 'materials' then 5
        else 1
    end::numeric;
$$;

-- Offset a point by a random distance up to radius_m, uniformly over the disc.
create function public.fuzz_point(p extensions.geography, radius_m double precision default 400)
returns extensions.geography
language sql
volatile
set search_path = ''
as $$
    select extensions.st_project(p, radius_m * sqrt(random()), radians(random() * 360))::extensions.geography;
$$;

create function public.items_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' or not extensions.st_equals(new.location::extensions.geometry, old.location::extensions.geometry) then
        new.location := public.fuzz_point(new.location);
    end if;
    if new.est_kg is null then
        new.est_kg := public.default_kg(new.category);
    end if;
    if tg_op = 'UPDATE' then
        new.owner_id := old.owner_id;
        new.updated_at := now();
    end if;
    return new;
end;
$$;

create trigger items_before_write
    before insert or update on public.items
    for each row execute function public.items_before_write();

-- Nearby feed. Runs as the caller, so RLS on items still applies.
create function public.nearby_items(
    lat double precision,
    lng double precision,
    radius_km double precision default 10,
    only_category public.item_category default null,
    only_mode public.item_mode default null,
    max_results integer default 50
)
returns table (
    id uuid,
    owner_id uuid,
    title text,
    details text,
    category public.item_category,
    condition public.item_condition,
    mode public.item_mode,
    status public.item_status,
    wants text,
    est_kg numeric,
    photos text[],
    created_at timestamptz,
    latitude double precision,
    longitude double precision,
    distance_km double precision
)
language sql
stable
set search_path = ''
as $$
    with origin as (
        select extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography as g
    )
    select
        i.id, i.owner_id, i.title, i.details, i.category, i.condition, i.mode, i.status,
        i.wants, i.est_kg, i.photos, i.created_at,
        extensions.st_y(i.location::extensions.geometry),
        extensions.st_x(i.location::extensions.geometry),
        extensions.st_distance(i.location, origin.g) / 1000
    from public.items i, origin
    where i.status = 'available'
      and extensions.st_dwithin(i.location, origin.g, least(radius_km, 100) * 1000)
      and (only_category is null or i.category = only_category)
      and (only_mode is null or i.mode = only_mode)
    order by extensions.st_distance(i.location, origin.g)
    limit least(max_results, 200);
$$;

-- ---------------------------------------------------------------------------
-- Swaps, conversations, messages
-- ---------------------------------------------------------------------------

create table public.swap_offers (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null references public.items (id) on delete cascade,
    offered_item_id uuid not null references public.items (id) on delete cascade,
    from_user uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    status public.swap_status not null default 'pending',
    created_at timestamptz not null default now(),
    check (item_id <> offered_item_id)
);

create index swap_offers_item_idx on public.swap_offers (item_id);

create table public.conversations (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null references public.items (id) on delete cascade,
    giver_id uuid not null references public.profiles (id) on delete cascade,
    receiver_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (item_id, receiver_id),
    check (giver_id <> receiver_id)
);

create table public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references public.conversations (id) on delete cascade,
    sender_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    body text not null check (char_length(body) between 1 and 2000),
    created_at timestamptz not null default now()
);

create index messages_conversation_idx on public.messages (conversation_id, created_at);

create function public.is_conversation_member(c uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.conversations
        where id = c and (select auth.uid()) in (giver_id, receiver_id)
    );
$$;

-- ---------------------------------------------------------------------------
-- Handoffs and impact
-- ---------------------------------------------------------------------------

create table public.handoffs (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null unique references public.items (id) on delete cascade,
    giver_id uuid not null references public.profiles (id) on delete cascade,
    receiver_id uuid not null references public.profiles (id) on delete cascade,
    confirmed_by_giver boolean not null default false,
    confirmed_by_receiver boolean not null default false,
    est_kg numeric(7, 2) not null,
    created_at timestamptz not null default now(),
    completed_at timestamptz,
    check (giver_id <> receiver_id)
);

create index handoffs_giver_idx on public.handoffs (giver_id);
create index handoffs_receiver_idx on public.handoffs (receiver_id);
create index handoffs_completed_idx on public.handoffs (completed_at) where completed_at is not null;

-- The item owner reserves an item for a receiver. Creates the pending handoff.
create function public.reserve_item(p_item_id uuid, p_receiver_id uuid)
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

-- Each side confirms its own half. When both have confirmed, the item is handed off.
create function public.confirm_handoff(p_handoff_id uuid)
returns public.handoffs
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_handoff public.handoffs;
begin
    select * into v_handoff from public.handoffs where id = p_handoff_id for update;
    if v_handoff.id is null or v_uid not in (v_handoff.giver_id, v_handoff.receiver_id) then
        raise exception 'Not part of this handoff' using errcode = '42501';
    end if;
    if v_handoff.completed_at is not null then
        return v_handoff;
    end if;

    update public.handoffs
    set confirmed_by_giver = confirmed_by_giver or v_uid = giver_id,
        confirmed_by_receiver = confirmed_by_receiver or v_uid = receiver_id
    where id = p_handoff_id
    returning * into v_handoff;

    if v_handoff.confirmed_by_giver and v_handoff.confirmed_by_receiver then
        update public.handoffs set completed_at = now() where id = p_handoff_id returning * into v_handoff;
        update public.items set status = 'handed_off' where id = v_handoff.item_id;
    end if;

    return v_handoff;
end;
$$;

-- Owner cancels a reservation that has not completed.
create function public.cancel_reservation(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not exists (select 1 from public.items where id = p_item_id and owner_id = (select auth.uid())) then
        raise exception 'Only the owner can cancel' using errcode = '42501';
    end if;
    delete from public.handoffs where item_id = p_item_id and completed_at is null;
    update public.items set status = 'available' where id = p_item_id and status = 'reserved';
end;
$$;

-- Personal impact for the signed-in user.
create function public.my_impact()
returns table (items_given bigint, items_received bigint, kg_diverted numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select
        count(*) filter (where giver_id = (select auth.uid())),
        count(*) filter (where receiver_id = (select auth.uid())),
        coalesce(sum(est_kg) filter (where giver_id = (select auth.uid())), 0)
    from public.handoffs
    where completed_at is not null
      and (select auth.uid()) in (giver_id, receiver_id);
$$;

-- Totals for everyone. Aggregates only, no row-level data leaves this function.
create function public.community_impact()
returns table (items_kept_moving bigint, kg_diverted numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select count(*), coalesce(sum(est_kg), 0)
    from public.handoffs
    where completed_at is not null;
$$;

-- ---------------------------------------------------------------------------
-- Places: donation, repair, e-waste, textile
-- ---------------------------------------------------------------------------

create table public.places (
    id uuid primary key default gen_random_uuid(),
    kind public.place_kind not null,
    name text not null,
    address text not null,
    location extensions.geography(point, 4326) not null,
    accepts public.item_category[] not null default '{}',
    hours text,
    website text,
    verified boolean not null default false,
    created_at timestamptz not null default now()
);

create index places_location_idx on public.places using gist (location);

-- ---------------------------------------------------------------------------
-- Challenges
-- ---------------------------------------------------------------------------

create table public.challenges (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    description text not null default '',
    goal_items integer not null check (goal_items > 0),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    -- Optional boundary. When null, the challenge is open to everyone.
    area extensions.geography(polygon, 4326),
    org_name text,
    created_at timestamptz not null default now(),
    check (ends_at > starts_at)
);

create table public.challenge_members (
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    joined_at timestamptz not null default now(),
    primary key (challenge_id, user_id)
);

-- Handoffs completed during the challenge window where the giver is a member.
-- When the challenge has an area, the item must have been listed inside it.
create function public.challenge_progress(p_challenge_id uuid)
returns table (items_kept_moving bigint, kg_diverted numeric, members bigint)
language sql
stable
security definer
set search_path = ''
as $$
    select
        (select count(*) from public.handoffs h
            join public.items i on i.id = h.item_id
            join public.challenge_members m on m.challenge_id = c.id and m.user_id = h.giver_id
            where h.completed_at between c.starts_at and c.ends_at
              and (c.area is null or extensions.st_covers(c.area, i.location))),
        (select coalesce(sum(h.est_kg), 0) from public.handoffs h
            join public.items i on i.id = h.item_id
            join public.challenge_members m on m.challenge_id = c.id and m.user_id = h.giver_id
            where h.completed_at between c.starts_at and c.ends_at
              and (c.area is null or extensions.st_covers(c.area, i.location))),
        (select count(*) from public.challenge_members m where m.challenge_id = c.id)
    from public.challenges c
    where c.id = p_challenge_id;
$$;

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

create table public.reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    target_type public.report_target not null,
    target_id uuid not null,
    reason text not null check (char_length(reason) between 1 and 1000),
    status public.report_status not null default 'open',
    created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Account deletion (App Store guideline 5.1.1(v))
-- ---------------------------------------------------------------------------

create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from auth.users where id = (select auth.uid());
end;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.blocks enable row level security;
alter table public.items enable row level security;
alter table public.swap_offers enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.handoffs enable row level security;
alter table public.places enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;
alter table public.reports enable row level security;

-- Profiles: anyone signed in can read; you edit only your own.
create policy "profiles readable" on public.profiles
    for select to authenticated using (true);
create policy "profiles self update" on public.profiles
    for update to authenticated
    using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Blocks: private to the blocker.
create policy "blocks own" on public.blocks
    for all to authenticated
    using (blocker_id = (select auth.uid())) with check (blocker_id = (select auth.uid()));

-- Items: you always see your own. Others see listed items from people not blocked either way.
create policy "items readable" on public.items
    for select to authenticated
    using (
        owner_id = (select auth.uid())
        or (status in ('available', 'reserved') and not public.is_blocked(owner_id, (select auth.uid())))
    );
create policy "items insert own" on public.items
    for insert to authenticated
    with check (owner_id = (select auth.uid()) and status = 'available');
-- Owners can edit and remove, but cannot set reserved or handed_off directly.
create policy "items update own" on public.items
    for update to authenticated
    using (owner_id = (select auth.uid()))
    with check (owner_id = (select auth.uid()) and status in ('available', 'removed'));
create policy "items delete own" on public.items
    for delete to authenticated using (owner_id = (select auth.uid()));

-- Swap offers: visible to the offerer and the listing owner.
create policy "swaps readable" on public.swap_offers
    for select to authenticated
    using (
        from_user = (select auth.uid())
        or exists (select 1 from public.items i where i.id = item_id and i.owner_id = (select auth.uid()))
    );
create policy "swaps insert" on public.swap_offers
    for insert to authenticated
    with check (
        from_user = (select auth.uid())
        and status = 'pending'
        and exists (select 1 from public.items i where i.id = offered_item_id and i.owner_id = (select auth.uid()))
        and exists (
            select 1 from public.items i
            where i.id = item_id and i.mode = 'swap' and i.status = 'available'
              and i.owner_id <> (select auth.uid())
              and not public.is_blocked(i.owner_id, (select auth.uid()))
        )
    );
create policy "swaps respond" on public.swap_offers
    for update to authenticated
    using (
        from_user = (select auth.uid())
        or exists (select 1 from public.items i where i.id = item_id and i.owner_id = (select auth.uid()))
    )
    with check (status in ('accepted', 'declined', 'withdrawn'));

-- Conversations: participants only. The receiver opens it, and the giver must own the item.
create policy "conversations readable" on public.conversations
    for select to authenticated
    using ((select auth.uid()) in (giver_id, receiver_id));
create policy "conversations open" on public.conversations
    for insert to authenticated
    with check (
        receiver_id = (select auth.uid())
        and exists (
            select 1 from public.items i
            where i.id = item_id and i.owner_id = giver_id and i.status = 'available'
        )
        and not public.is_blocked(giver_id, receiver_id)
    );

-- Messages: participants only, and not after a block.
create policy "messages readable" on public.messages
    for select to authenticated
    using (public.is_conversation_member(conversation_id));
create policy "messages send" on public.messages
    for insert to authenticated
    with check (
        sender_id = (select auth.uid())
        and public.is_conversation_member(conversation_id)
        and not exists (
            select 1 from public.conversations c
            where c.id = conversation_id and public.is_blocked(c.giver_id, c.receiver_id)
        )
    );

-- Handoffs: participants can read. All writes go through reserve_item, confirm_handoff, cancel_reservation.
create policy "handoffs readable" on public.handoffs
    for select to authenticated
    using ((select auth.uid()) in (giver_id, receiver_id));

-- Places and challenges: public reference data, written by the service role only.
create policy "places readable" on public.places
    for select to anon, authenticated using (true);
create policy "challenges readable" on public.challenges
    for select to anon, authenticated using (true);

-- Challenge membership: readable for counts, join and leave yourself.
create policy "members readable" on public.challenge_members
    for select to authenticated using (true);
create policy "members join" on public.challenge_members
    for insert to authenticated with check (user_id = (select auth.uid()));
create policy "members leave" on public.challenge_members
    for delete to authenticated using (user_id = (select auth.uid()));

-- Reports: file your own, see your own. Moderators use the service role.
create policy "reports file" on public.reports
    for insert to authenticated with check (reporter_id = (select auth.uid()) and status = 'open');
create policy "reports own" on public.reports
    for select to authenticated using (reporter_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Function privileges: callable by signed-in users only
-- ---------------------------------------------------------------------------

revoke execute on function public.reserve_item(uuid, uuid) from public, anon;
revoke execute on function public.confirm_handoff(uuid) from public, anon;
revoke execute on function public.cancel_reservation(uuid) from public, anon;
revoke execute on function public.my_impact() from public, anon;
revoke execute on function public.delete_account() from public, anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

grant execute on function public.reserve_item(uuid, uuid) to authenticated;
grant execute on function public.confirm_handoff(uuid) to authenticated;
grant execute on function public.cancel_reservation(uuid) to authenticated;
grant execute on function public.my_impact() to authenticated;
grant execute on function public.delete_account() to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime for chat and challenge progress
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.handoffs;

-- ---------------------------------------------------------------------------
-- Storage: item photos under item-photos/<user id>/<file>
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('item-photos', 'item-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do nothing;

create policy "item photos upload own folder" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'item-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "item photos delete own" on storage.objects
    for delete to authenticated
    using (bucket_id = 'item-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
