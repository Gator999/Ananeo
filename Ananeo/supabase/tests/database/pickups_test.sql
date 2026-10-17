-- Pickup requests, reservations, and handoff confirmation from both sides.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(35);

-- Users -----------------------------------------------------------------------
-- Alice gives. Bob, Carol, and Dave ask. Erin only shows up later.
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}'),
    ('00000000-0000-0000-0000-00000000000c', 'carol@test.local', 'authenticated', 'authenticated', '{"full_name":"Carol"}'),
    ('00000000-0000-0000-0000-00000000000d', 'dave@test.local',  'authenticated', 'authenticated', '{"full_name":"Dave"}'),
    ('00000000-0000-0000-0000-00000000000e', 'erin@test.local',  'authenticated', 'authenticated', '{"full_name":"Erin"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location, photos) values
    ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)', '{alice/shelf.jpg,alice/shelf-2.jpg}'),
    ('10000000-0000-0000-0000-000000000002', 'Desk lamp', 'household', 'SRID=4326;POINT(-73.9442 40.6782)', '{}'),
    ('10000000-0000-0000-0000-000000000003', 'Kitchen chair', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)', '{}');

-- Requests --------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select set_eq(
    $$select other_name, is_giver, title, photo, item_status::text from my_pickups()$$,
    $$values ('Bob', true, 'Oak bookshelf', 'alice/shelf.jpg', 'available'),
             ('Carol', true, 'Oak bookshelf', 'alice/shelf.jpg', 'available'),
             ('Dave', true, 'Oak bookshelf', 'alice/shelf.jpg', 'available')$$,
    'giver sees everyone who asked');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select other_name, is_giver, item_status::text, handoff_id from my_pickups()$$,
    $$values ('Alice', false, 'available', null::uuid)$$,
    'receiver sees only their own request, with the giver as the other person');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000e');
select is((select count(*) from my_pickups()), 0::bigint, 'outsiders have no pickups');

-- Reserving -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok(
    $$select reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000e')$$,
    'P0001', 'This person has not asked for the item', 'can only reserve for someone who asked');
select lives_ok(
    $$select reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$$,
    'giver reserves for a requester');

update items set status = 'available' where id = '10000000-0000-0000-0000-000000000001';
update items set status = 'removed' where id = '10000000-0000-0000-0000-000000000001';
update items set title = 'Renamed' where id = '10000000-0000-0000-0000-000000000001';
select results_eq(
    $$select status::text, title from items where id = '10000000-0000-0000-0000-000000000001'$$,
    $$values ('reserved', 'Oak bookshelf')$$,
    'a reserved item cannot be reopened, removed, or edited directly');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000e');
select throws_ok(
    $$insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a')$$,
    '42501', null, 'nobody can ask for a reserved item');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select handoff_id is not null, confirmed_by_me, confirmed_by_them, completed_at from my_pickups()$$,
    $$values (true, false, false, null::timestamptz)$$,
    'receiver sees the reservation');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select results_eq(
    $$select item_status::text, handoff_id from my_pickups()$$,
    $$values ('reserved', null::uuid)$$,
    'other requesters see it reserved, without the handoff');

-- The receiver backs out ------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select lives_ok($$select withdraw_request('10000000-0000-0000-0000-000000000001')$$, 'receiver backs out of a reservation');

set local role postgres;
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000001'), 'available', 'backing out makes the item available again');
select is((select count(*) from handoffs), 0::bigint, 'backing out deletes the pending handoff');
select is((select count(*) from conversations where receiver_id = '00000000-0000-0000-0000-00000000000b'), 0::bigint, 'backing out deletes the request');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select set_eq($$select other_name from my_pickups()$$, $$values ('Carol'), ('Dave')$$, 'withdrawn requests disappear for the giver');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select lives_ok($$select withdraw_request('10000000-0000-0000-0000-000000000001')$$, 'withdrawing twice is harmless');

-- Both sides confirm ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
create temp table h as select * from reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c');
grant select on h to authenticated;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select lives_ok(format('select confirm_handoff(%L)', (select id from h)), 'receiver confirms first');
select results_eq(
    $$select confirmed_by_me, confirmed_by_them from my_pickups()$$,
    $$values (true, false)$$,
    'receiver sees their own confirmation');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select other_name, confirmed_by_me, confirmed_by_them from my_pickups() where handoff_id is not null$$,
    $$values ('Carol', false, true)$$,
    'giver sees that the receiver confirmed');
select lives_ok(format('select confirm_handoff(%L)', (select id from h)), 'giver confirms');
select results_eq(
    $$select other_name, item_status::text, completed_at is not null from my_pickups()$$,
    $$values ('Carol', 'handed_off', true)$$,
    'after the handoff, the giver sees only who got it');

update items set status = 'available' where id = '10000000-0000-0000-0000-000000000001';
set local role postgres;
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000001'), 'handed_off', 'a handed-off item cannot be re-listed');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select results_eq(
    $$select other_name, item_status::text, completed_at is not null from my_pickups()$$,
    $$values ('Alice', 'handed_off', true)$$,
    'receiver sees the completed pickup');
select throws_ok(
    $$select withdraw_request('10000000-0000-0000-0000-000000000001')$$,
    'P0001', 'This pickup is already complete', 'a completed pickup cannot be withdrawn');
select results_eq(
    'select items_given, items_received from my_impact()',
    $$values (0::bigint, 1::bigint)$$,
    'receiver impact counts the pickup');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select results_eq(
    $$select item_status::text, handoff_id from my_pickups()$$,
    $$values ('handed_off', null::uuid)$$,
    'other requesters see it was given away');
select lives_ok($$select withdraw_request('10000000-0000-0000-0000-000000000001')$$, 'other requesters can clear it from their list');
select is((select count(*) from my_pickups()), 0::bigint, 'cleared requests are gone');

-- Removed items ---------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
update items set status = 'removed' where id = '10000000-0000-0000-0000-000000000002';
select is((select count(*) from my_pickups() where item_id = '10000000-0000-0000-0000-000000000002'), 0::bigint, 'givers stop seeing requests on removed items');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select title, item_status::text from my_pickups()$$,
    $$values ('Desk lamp', 'removed')$$,
    'requesters see the item was removed');

-- Blocks ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000e');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000a');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok(
    $$select reserve_item('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000e')$$,
    'giver reserves the chair');
insert into blocks (blocker_id, blocked_id) values
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'),
    ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
select set_eq(
    $$select other_name from my_pickups() where item_id = '10000000-0000-0000-0000-000000000003'$$,
    $$values ('Erin')$$,
    'a block hides open requests but keeps a reservation visible');
select lives_ok($$select cancel_reservation('10000000-0000-0000-0000-000000000003')$$, 'giver can still cancel it');
select is((select count(*) from my_pickups() where item_id = '10000000-0000-0000-0000-000000000003'), 0::bigint, 'once cancelled, the blocked request is hidden too');

-- Privileges ------------------------------------------------------------------
set local role postgres;
set local role anon;
select throws_ok('select * from my_pickups()', '42501', null, 'signed-out users cannot list pickups');
select throws_ok(
    $$select withdraw_request('10000000-0000-0000-0000-000000000001')$$,
    '42501', null, 'signed-out users cannot withdraw');

select * from finish();
rollback;
