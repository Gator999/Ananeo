-- Chat on pickup requests: who can send, what clients control, and unread counts.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

-- Users -----------------------------------------------------------------------
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

-- What clients control --------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into conversations (item_id, giver_id, giver_read_at)
      values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'infinity')$$,
    '42501', null, 'a requester cannot set the giver''s read marker');
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');

select lives_ok(
    $$insert into messages (id, conversation_id, body)
      values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Could I pick it up Saturday?')$$,
    'a participant sends a message with an ID they chose');
select is((select sender_id from messages where id = '30000000-0000-0000-0000-000000000001'), '00000000-0000-0000-0000-00000000000b'::uuid, 'the sender is the caller');
select throws_ok(
    $$insert into messages (conversation_id, body, created_at) values ('20000000-0000-0000-0000-000000000001', 'old news', now() - interval '1 day')$$,
    '42501', null, 'messages cannot be backdated');
select throws_ok(
    $$insert into messages (conversation_id, body, sender_id) values ('20000000-0000-0000-0000-000000000001', 'hi', '00000000-0000-0000-0000-00000000000a')$$,
    '42501', null, 'messages cannot claim another sender');

-- Unread counts and previews --------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select unread_count, last_message, last_message_mine from my_pickups()$$,
    $$values (1::bigint, 'Could I pick it up Saturday?', false)$$,
    'the giver has one unread message');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select unread_count, last_message_mine from my_pickups()$$,
    $$values (0::bigint, true)$$,
    'your own messages are never unread');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok($$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$, 'the giver opens the chat');
select is((select unread_count from my_pickups()), 0::bigint, 'opening the chat clears unread');
select is((select receiver_read_at from conversations where id = '20000000-0000-0000-0000-000000000001'), null, 'only the caller''s read marker moves');

-- Same timestamp as the first message, so the ID decides which is latest.
insert into messages (id, conversation_id, body)
values ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Saturday works.');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select unread_count, last_message, last_message_mine from my_pickups()$$,
    $$values (1::bigint, 'Saturday works.', false)$$,
    'the reply is unread for the requester');

-- Messages after the read marker count again. Everything in this transaction shares now(), so
-- this one is written with a later timestamp directly.
set local role postgres;
insert into messages (conversation_id, sender_id, body, created_at)
values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'See you at 10.', now() + interval '1 minute');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select unread_count, last_message from my_pickups()$$,
    $$values (1::bigint, 'See you at 10.')$$,
    'a message after the read marker is unread');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select lives_ok($$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$, 'an outsider calling mark read does nothing harmful');
select is((select count(*) from messages), 0::bigint, 'outsiders cannot read the chat');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is((select unread_count from my_pickups()), 1::bigint, 'an outsider cannot mark someone else''s chat read');

-- Ordering by latest activity -------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a');
insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000002', 'Is the lamp still around?');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select title from my_pickups()$$,
    $$values ('Oak bookshelf'), ('Desk lamp')$$,
    'the chat with the newest message comes first');

-- Chat continues after a reservation ------------------------------------------
select lives_ok(
    $$select reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$$,
    'the giver reserves the bookshelf');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select lives_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'On my way.')$$,
    'participants can keep chatting about a reserved item');

-- Withdrawing removes the chat ------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select lives_ok($$select withdraw_request('10000000-0000-0000-0000-000000000002')$$, 'a requester withdraws');
set local role postgres;
select is((select count(*) from messages where conversation_id = '20000000-0000-0000-0000-000000000002'), 0::bigint, 'withdrawing deletes the chat');

-- Blocks ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'hello?')$$,
    '42501', null, 'a blocked person cannot send messages');

-- Privileges ------------------------------------------------------------------
set local role postgres;
set local role anon;
select throws_ok(
    $$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$,
    '42501', null, 'signed-out users cannot mark chats read');

select * from finish();
rollback;
