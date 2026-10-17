-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(29);

-- Users -----------------------------------------------------------------------
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{}'),
    ('00000000-0000-0000-0000-00000000000c', 'carol@test.local', 'authenticated', 'authenticated', '{}');

select is((select display_name from profiles where id = '00000000-0000-0000-0000-00000000000a'), 'Alice', 'profile created from Apple full name');
select is((select display_name from profiles where id = '00000000-0000-0000-0000-00000000000b'), 'Neighbor', 'profile falls back to Neighbor');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

-- Alice lists a bookshelf in Brooklyn -----------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location)
values ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)');

reset role;
select ok(
    (select st_distance(location, 'SRID=4326;POINT(-73.9442 40.6782)'::geography) from items where id = '10000000-0000-0000-0000-000000000001') <= 401,
    'stored location stays within 400 m of the real point');
select ok(
    (select not st_equals(location::geometry, 'SRID=4326;POINT(-73.9442 40.6782)'::geometry) from items where id = '10000000-0000-0000-0000-000000000001'),
    'exact point is never stored');
select is((select est_kg from items where id = '10000000-0000-0000-0000-000000000001'), 25.00::numeric(7,2), 'weight defaults from category');
select is((select owner_id from items where id = '10000000-0000-0000-0000-000000000001'), '00000000-0000-0000-0000-00000000000a'::uuid, 'owner defaults to caller');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok(
    $$update items set status = 'reserved' where id = '10000000-0000-0000-0000-000000000001'$$,
    '42501', null, 'owner cannot set reserved directly');

-- Bob browses nearby ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select is((select count(*) from nearby_items(40.6782, -73.9442, 5)), 1::bigint, 'nearby feed finds the item');
select ok((select distance_km from nearby_items(40.6782, -73.9442, 5)) < 0.5, 'distance reported in km');
select is((select count(*) from nearby_items(40.6782, -73.9442, 5, 'books')), 0::bigint, 'category filter applies');
select is((select count(*) from nearby_items(40.7580, -73.9855, 5)), 0::bigint, 'items outside the radius are excluded');

update items set title = 'hacked' where id = '10000000-0000-0000-0000-000000000001';
reset role;
select is((select title from items where id = '10000000-0000-0000-0000-000000000001'), 'Oak bookshelf', 'others cannot edit an item');

-- Blocking hides listings both ways --------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
select is((select count(*) from nearby_items(40.6782, -73.9442, 5)), 0::bigint, 'blocked owner listings are hidden');
delete from blocks where blocker_id = '00000000-0000-0000-0000-00000000000b';

-- Bob opens a conversation -----------------------------------------------------
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'Can I pick it up Saturday?');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is((select count(*) from messages), 0::bigint, 'outsiders cannot read messages');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'hi')$$,
    '42501', null, 'outsiders cannot post into a conversation');

-- Reservation and two-sided handoff -------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$select reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$$,
    '42501', null, 'only the owner can reserve');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
create temp table h as select * from reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
grant select on h to authenticated;
select is((select status from items where id = '10000000-0000-0000-0000-000000000001'), 'reserved'::item_status, 'reserving marks the item reserved');

select confirm_handoff((select id from h));
select is((select completed_at from handoffs), null, 'one confirmation is not enough');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is((select count(*) from handoffs), 0::bigint, 'outsiders cannot see handoffs');
select throws_ok(format('select confirm_handoff(%L)', (select id from h)), '42501', null, 'outsiders cannot confirm');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select confirm_handoff((select id from h));
select isnt((select completed_at from handoffs), null, 'both confirmations complete the handoff');

reset role;
select is((select status from items where id = '10000000-0000-0000-0000-000000000001'), 'handed_off'::item_status, 'item is marked handed off');

-- Impact ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq('select items_given, items_received, kg_diverted from my_impact()', $$values (1::bigint, 0::bigint, 25.00::numeric)$$, 'giver impact counts the item and weight');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq('select items_given, items_received from my_impact()', $$values (0::bigint, 1::bigint)$$, 'receiver impact counts the item');
select results_eq('select items_kept_moving, kg_diverted from community_impact()', $$values (1::bigint, 25.00::numeric)$$, 'community total');

-- Challenge progress ----------------------------------------------------------
reset role;
insert into challenges (id, title, goal_items, starts_at, ends_at)
values ('30000000-0000-0000-0000-000000000001', 'Move-out Week', 500, now() - interval '1 day', now() + interval '6 days');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into challenge_members (challenge_id) values ('30000000-0000-0000-0000-000000000001');
select results_eq(
    $$select items_kept_moving, members from challenge_progress('30000000-0000-0000-0000-000000000001')$$,
    $$values (1::bigint, 1::bigint)$$, 'challenge counts handoffs by members');

-- Privileges ------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from items', '42501', null, 'signed-out users cannot read items');
select lives_ok('select count(*) from places', 'signed-out users can read places');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok(
    $$update profiles set created_at = now() - interval '10 years' where id = '00000000-0000-0000-0000-00000000000a'$$,
    '42501', null, 'profile columns outside the allowed set cannot be changed');

select * from finish();
rollback;
