-- What the website reads before and after sign-in.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}');

-- Two places near downtown Brooklyn and one far away, written as the service role would.
insert into places (name, kind, address, location, accepts) values
    ('Community Thrift', 'donation', '120 Main St', 'SRID=4326;POINT(-73.9900 40.6930)', '{clothing,books,household}'),
    ('E-Waste Depot', 'ewaste', '900 Recycling Way', 'SRID=4326;POINT(-73.9500 40.6700)', '{electronics}'),
    ('Far Away ReStore', 'donation', '1 Distant Rd', 'SRID=4326;POINT(-118.2437 34.0522)', '{furniture}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

-- A completed handoff so the community total is not zero.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location) values
    ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
select confirm_handoff((select id from handoffs where item_id = '10000000-0000-0000-0000-000000000001'));
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select confirm_handoff((select id from handoffs where item_id = '10000000-0000-0000-0000-000000000001'));

-- Signed out ------------------------------------------------------------------
set local role anon;
select results_eq(
    $$select items_kept_moving, kg_diverted from community_impact()$$,
    $$values (1::bigint, 25::numeric)$$,
    'signed-out visitors can read the community total');
select throws_ok(
    $$select * from my_impact()$$,
    '42501', null, 'signed-out visitors cannot read personal impact');
select throws_ok(
    $$select * from nearby_items(40.6782, -73.9442)$$,
    '42501', null, 'signed-out visitors cannot browse items');
select results_eq(
    $$select name, kind::text from nearby_places(40.6782, -73.9442)$$,
    $$values ('E-Waste Depot', 'ewaste'), ('Community Thrift', 'donation')$$,
    'signed-out visitors see nearby places, closest first, and nothing far away');
select results_eq(
    $$select name from nearby_places(40.6782, -73.9442, 25, 'ewaste')$$,
    $$values ('E-Waste Depot')$$,
    'places can be filtered by kind');
select is(
    (select round(distance_km::numeric, 1) from nearby_places(40.6782, -73.9442) where name = 'Community Thrift'),
    4.2, 'distance is measured in kilometers from the caller');

-- Signed in -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select is((select count(*) from nearby_places(40.6782, -73.9442)), 2::bigint, 'signed-in users see the same places');
select results_eq(
    $$select items_received from my_impact()$$,
    $$values (1::bigint)$$,
    'signed-in users still read their own impact');

select * from finish();
rollback;
