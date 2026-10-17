-- Reporting, blocking, and moderation, as App Store guideline 1.2 requires for user-generated content.

-- ---------------------------------------------------------------------------
-- Blocks
-- ---------------------------------------------------------------------------

alter table public.blocks alter column blocker_id set default auth.uid();

-- Blocking someone ends any pickup in progress between the two of you, in either direction.
-- Completed handoffs stay, so impact history is unchanged.
create function public.blocks_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.items i
    set status = 'available'
    from public.handoffs h
    where h.item_id = i.id
      and h.completed_at is null
      and i.status = 'reserved'
      and ((h.giver_id = new.blocker_id and h.receiver_id = new.blocked_id)
        or (h.giver_id = new.blocked_id and h.receiver_id = new.blocker_id));

    delete from public.handoffs
    where completed_at is null
      and ((giver_id = new.blocker_id and receiver_id = new.blocked_id)
        or (giver_id = new.blocked_id and receiver_id = new.blocker_id));

    return null;
end;
$$;

create trigger blocks_after_insert
    after insert on public.blocks
    for each row execute function public.blocks_after_insert();

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

-- One report per person per thing. Reporting it again changes nothing.
alter table public.reports add constraint reports_once unique (reporter_id, target_type, target_id);

create index reports_open_idx on public.reports (target_type, target_id) where status = 'open';

-- You can report only what someone else posted and you can see: a listing in your feed, a message
-- in one of your chats, or another person.
alter policy "reports file" on public.reports
    with check (
        reporter_id = (select auth.uid())
        and status = 'open'
        and case target_type
            when 'item' then exists (
                select 1 from public.items i where i.id = target_id and i.owner_id <> (select auth.uid())
            )
            when 'message' then exists (
                select 1 from public.messages m where m.id = target_id and m.sender_id <> (select auth.uid())
            )
            when 'user' then exists (
                select 1 from public.profiles p where p.id = target_id and p.id <> (select auth.uid())
            )
        end
    );

revoke insert on public.reports from authenticated;
grant insert (target_type, target_id, reason) on public.reports to authenticated;

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------

-- Moderators are added by hand in the SQL editor:
--   insert into public.moderators (user_id) values ('<auth user id>');
-- No policies or grants, so only the functions below can read it.
create table public.moderators (
    user_id uuid primary key references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.moderators enable row level security;
revoke all on public.moderators from anon, authenticated;

alter table public.profiles add column banned_at timestamptz;

create function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (select 1 from public.moderators where user_id = (select auth.uid()));
$$;

-- Open reports grouped by what was reported, oldest first. Empty for anyone but a moderator.
-- The subject is the person responsible: the listing's owner, the message's sender, or the
-- reported person. Summary and subject are null if the content is already gone.
create function public.moderation_queue()
returns table (
    target_type public.report_target,
    target_id uuid,
    subject_id uuid,
    subject_name text,
    subject_banned boolean,
    summary text,
    photo text,
    report_count bigint,
    reasons text[],
    first_reported_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    with open_reports as (
        select
            r.target_type,
            r.target_id,
            count(*) as report_count,
            array_agg(r.reason order by r.created_at) as reasons,
            min(r.created_at) as first_reported_at
        from public.reports r
        where r.status = 'open'
        group by r.target_type, r.target_id
    )
    select
        o.target_type,
        o.target_id,
        s.id,
        s.display_name,
        s.banned_at is not null,
        case o.target_type
            when 'item' then i.title
            when 'message' then m.body
            when 'user' then s.display_name
        end,
        i.photos[1],
        o.report_count,
        o.reasons,
        o.first_reported_at
    from open_reports o
    left join public.items i on o.target_type = 'item' and i.id = o.target_id
    left join public.messages m on o.target_type = 'message' and m.id = o.target_id
    left join public.profiles s on s.id = case o.target_type
        when 'item' then i.owner_id
        when 'message' then m.sender_id
        when 'user' then o.target_id
    end
    where public.is_moderator()
    order by o.first_reported_at;
$$;

-- Resolves every open report on one target.
--   dismiss: keeps the content.
--   remove:  takes down a listing, ending any pickup in progress, or deletes a message.
--   ban:     removes the content too, then bans the person responsible. Their open listings come
--            down, pickups in progress with them end, and they are signed out and can't sign in.
create function public.moderate(p_target_type public.report_target, p_target_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_subject uuid;
begin
    if not public.is_moderator() then
        raise exception 'Moderators only' using errcode = '42501';
    end if;
    if p_action not in ('dismiss', 'remove', 'ban') then
        raise exception 'Unknown moderation action: %', p_action;
    end if;

    v_subject := case p_target_type
        when 'item' then (select owner_id from public.items where id = p_target_id)
        when 'message' then (select sender_id from public.messages where id = p_target_id)
        when 'user' then p_target_id
    end;

    if p_action in ('remove', 'ban') then
        if p_target_type = 'item' then
            delete from public.handoffs where item_id = p_target_id and completed_at is null;
            update public.items set status = 'removed' where id = p_target_id and status in ('available', 'reserved');
        elsif p_target_type = 'message' then
            delete from public.messages where id = p_target_id;
        end if;
    end if;

    if p_action = 'ban' then
        if v_subject is null then
            raise exception 'The person responsible no longer exists';
        end if;

        update public.profiles set banned_at = now() where id = v_subject and banned_at is null;

        -- Items other people reserved for them go back on the feed.
        update public.items i
        set status = 'available'
        from public.handoffs h
        where h.item_id = i.id and h.completed_at is null and h.receiver_id = v_subject and i.status = 'reserved';
        delete from public.handoffs where completed_at is null and v_subject in (giver_id, receiver_id);
        update public.items set status = 'removed' where owner_id = v_subject and status in ('available', 'reserved');

        -- Auth refuses banned users at sign-in and token refresh. Deleting their sessions revokes
        -- refresh tokens, so they are out once their current access token expires (within an hour).
        update auth.users set banned_until = now() + interval '100 years' where id = v_subject;
        delete from auth.sessions where user_id = v_subject;
    end if;

    update public.reports
    set status = case when p_action = 'dismiss' then 'dismissed' else 'actioned' end::public.report_status
    where target_type = p_target_type and target_id = p_target_id and status = 'open';
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. New functions are executable by everyone by default, so start from nothing.
-- ---------------------------------------------------------------------------

revoke execute on function public.blocks_after_insert() from public, anon, authenticated;
revoke execute on function public.is_moderator() from public, anon, authenticated;
revoke execute on function public.moderation_queue() from public, anon, authenticated;
revoke execute on function public.moderate(public.report_target, uuid, text) from public, anon, authenticated;

grant execute on function public.is_moderator() to authenticated;
grant execute on function public.moderation_queue() to authenticated;
grant execute on function public.moderate(public.report_target, uuid, text) to authenticated;
