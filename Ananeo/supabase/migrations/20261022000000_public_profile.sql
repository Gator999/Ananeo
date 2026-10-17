-- A person's public card: their display name and how many handoffs they have completed, from either
-- side. Shown on a listing as the giver card, and later in the chat header.
-- Aggregates only, so no handoff rows leave this function. A block in either direction hides the card.

create function public.public_profile(p_user_id uuid)
returns table (id uuid, display_name text, items_kept_moving bigint, member_since timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
    select
        p.id,
        p.display_name,
        (select count(*) from public.handoffs h
            where h.completed_at is not null and p.id in (h.giver_id, h.receiver_id)),
        p.created_at
    from public.profiles p
    where p.id = p_user_id
      and not public.is_blocked(p.id, (select auth.uid()));
$$;

-- New functions are executable by everyone by default, so start from nothing.
revoke execute on function public.public_profile(uuid) from public, anon, authenticated;
grant execute on function public.public_profile(uuid) to authenticated;
