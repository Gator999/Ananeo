-- Terms of use acceptance. The terms ship in the app (Shared/TermsOfUse.swift) with a version
-- number. People accept each version once, and the app asks again when the version goes up.

create table public.terms_acceptances (
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    version integer not null check (version > 0),
    accepted_at timestamptz not null default now(),
    primary key (user_id, version)
);

alter table public.terms_acceptances enable row level security;

create policy "terms own" on public.terms_acceptances
    for select to authenticated
    using (user_id = (select auth.uid()));

-- Records that the signed-in user accepted a version of the terms. Accepting again is harmless.
create function public.accept_terms(p_version integer)
returns void
language sql
security definer
set search_path = ''
as $$
    insert into public.terms_acceptances (user_id, version)
    values ((select auth.uid()), p_version)
    on conflict (user_id, version) do nothing;
$$;

-- The newest version of the terms the signed-in user has accepted, or 0 if none.
create function public.my_terms_version()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(max(version), 0)
    from public.terms_acceptances
    where user_id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Privileges. New tables and functions start open to everyone, so start from nothing.
-- Acceptances are written only through accept_terms.
-- ---------------------------------------------------------------------------

revoke all on public.terms_acceptances from anon, authenticated;
grant select on public.terms_acceptances to authenticated;

revoke execute on function public.accept_terms(integer) from public, anon, authenticated;
revoke execute on function public.my_terms_version() from public, anon, authenticated;

grant execute on function public.accept_terms(integer) to authenticated;
grant execute on function public.my_terms_version() to authenticated;
