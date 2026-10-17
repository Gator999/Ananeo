-- The public profile card: display name and completed-handoff count, hidden by blocks.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(9);

-- Users -----------------------------------------------------------------------
-- Alice gives a shelf to Bob, and reserves a lamp for Carol that is never picked up.
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}'),
    ('00000000-0000-0000-0000-00000000000c', 'carol@test.local', 'authenticated', 'authenticated', '{"full_name":"Carol"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location) values
    ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)'),
    ('10000000-0000-0000-0000-000000000002', 'Desk lamp', 'household', 'SRID=4326;POINT(-73.9442 40.6782)');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a');

-- The shelf is handed off, both sides confirmed. The lamp stays reserved.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
create temp table h as select * from reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
grant select on h to authenticated;
select reserve_item('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000c');
select confirm_handoff((select id from h));
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select confirm_handoff((select id from h));

-- Counts ----------------------------------------------------------------------
select results_eq(
    $$select display_name, items_kept_moving from public_profile('00000000-0000-0000-0000-00000000000a')$$,
    $$values ('Alice', 1::bigint)$$,
    'a requester sees the giver''s name and completed handoffs');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select display_name, items_kept_moving from public_profile('00000000-0000-0000-0000-00000000000b')$$,
    $$values ('Bob', 1::bigint)$$,
    'receiving counts as keeping an item moving too');
select results_eq(
    $$select display_name, items_kept_moving from public_profile('00000000-0000-0000-0000-00000000000c')$$,
    $$values ('Carol', 0::bigint)$$,
    'a reservation that has not completed does not count');
select results_eq(
    $$select display_name, items_kept_moving from public_profile('00000000-0000-0000-0000-00000000000a')$$,
    $$values ('Alice', 1::bigint)$$,
    'you can look up your own card');
select is(
    (select count(*) from public_profile('00000000-0000-0000-0000-0000000000ff')),
    0::bigint,
    'an unknown id returns no card');

-- Blocks ----------------------------------------------------------------------
insert into blocks (blocker_id, blocked_id) values
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c');
select is(
    (select count(*) from public_profile('00000000-0000-0000-0000-00000000000c')),
    0::bigint,
    'the blocker does not see the blocked person''s card');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is(
    (select count(*) from public_profile('00000000-0000-0000-0000-00000000000a')),
    0::bigint,
    'the blocked person does not see the blocker''s card');

-- Privileges ------------------------------------------------------------------
set local role postgres;
set local role anon;
select throws_ok(
    $$select * from public_profile('00000000-0000-0000-0000-00000000000a')$$,
    '42501', null, 'signed-out users cannot look up cards');
set local role postgres;
select is(
    (select count(*) from information_schema.routine_privileges
        where routine_name = 'public_profile' and grantee in ('PUBLIC', 'anon')),
    0::bigint,
    'public_profile is not executable by public or anon');

select * from finish();
rollback;
