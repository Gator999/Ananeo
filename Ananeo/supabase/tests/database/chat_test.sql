-- Chat: only the two people in a pickup request can read or send its messages.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

-- Users -----------------------------------------------------------------------
-- Alice gives. Bob and Carol each ask for the same bookshelf. Dave is not part of any pickup.
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}'),
    ('00000000-0000-0000-0000-00000000000c', 'carol@test.local', 'authenticated', 'authenticated', '{"full_name":"Carol"}'),
    ('00000000-0000-0000-0000-00000000000d', 'dave@test.local',  'authenticated', 'authenticated', '{"full_name":"Dave"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location)
values ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)');

-- Opening a request -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
    $$insert into conversations (item_id, giver_id, receiver_id)
      values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')$$,
    '42501', null, 'nobody can open a request on behalf of someone else');
select throws_ok(
    $$insert into conversations (item_id, giver_id)
      values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c')$$,
    '42501', null, 'the giver on a request must own the item');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'Can I pick it up Saturday?');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000c', 'Is it still free?');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'Saturday works')$$,
    'the giver can reply in a request for their item');

-- Reading -----------------------------------------------------------------------
select is((select count(*) from messages), 3::bigint, 'the giver reads every request on their item');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select set_eq(
    'select body from messages',
    $$values ('Can I pick it up Saturday?'), ('Saturday works')$$,
    'a requester reads only their own conversation');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select results_eq(
    'select body from messages',
    $$values ('Is it still free?')$$,
    'another requester on the same item cannot read it');
select is(
    (select count(*) from conversations where id = '20000000-0000-0000-0000-00000000000b'), 0::bigint,
    'another requester cannot see the other request');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is((select count(*) from messages), 0::bigint, 'outsiders read no messages');
select is((select count(*) from conversations), 0::bigint, 'outsiders see no requests');

-- Sending -----------------------------------------------------------------------
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'hi')$$,
    '42501', null, 'outsiders cannot send');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'I can come sooner')$$,
    '42501', null, 'another requester cannot send into the other request');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into messages (conversation_id, sender_id, body)
      values ('20000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', 'Actually, never mind')$$,
    '42501', null, 'a participant cannot send as the other person');

-- Messages are permanent once sent ----------------------------------------------
select throws_ok(
    $$update messages set body = 'edited' where conversation_id = '20000000-0000-0000-0000-00000000000b'$$,
    '42501', null, 'messages cannot be edited');
select throws_ok(
    $$delete from messages where conversation_id = '20000000-0000-0000-0000-00000000000b'$$,
    '42501', null, 'messages cannot be deleted');
select throws_ok(
    $$update conversations set receiver_id = '00000000-0000-0000-0000-00000000000d' where id = '20000000-0000-0000-0000-00000000000b'$$,
    '42501', null, 'a request cannot be handed to someone else');

-- Blocking ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'hello?')$$,
    '42501', null, 'the blocker cannot send after a block');
select lives_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000c', 'Yes, still free')$$,
    'blocking one requester leaves the others open');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-00000000000b', 'hello?')$$,
    '42501', null, 'the blocked person cannot send after a block');
select is(
    (select count(*) from messages), 2::bigint,
    'earlier messages stay readable to the participants after a block');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is((select count(*) from messages), 0::bigint, 'a block does not expose anything to outsiders');

-- Signed out --------------------------------------------------------------------
set local role postgres;
set local role anon;
select throws_ok('select count(*) from messages', '42501', null, 'signed-out users cannot read messages');
select throws_ok('select count(*) from conversations', '42501', null, 'signed-out users cannot read requests');

select * from finish();
rollback;
