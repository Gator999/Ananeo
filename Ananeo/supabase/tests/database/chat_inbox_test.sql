-- Chat on pickup requests: who can talk, read state, and the inbox summary.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

-- Users -----------------------------------------------------------------------
-- Alice gives. Bob asks. Erin is an outsider.
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}'),
    ('00000000-0000-0000-0000-00000000000e', 'erin@test.local',  'authenticated', 'authenticated', '{"full_name":"Erin"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location) values
    ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (id, item_id, giver_id) values
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');

-- Sending ---------------------------------------------------------------------
select is((select count(*) from my_chats()), 0::bigint, 'a request with no messages is not in the inbox');

select lives_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'Is Saturday ok?')$$,
    'requester can message the giver');
select is(
    (select sender_id from messages where body = 'Is Saturday ok?'),
    '00000000-0000-0000-0000-00000000000b'::uuid,
    'the server stamps the sender');
select throws_ok(
    $$insert into messages (conversation_id, sender_id, body) values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'fake')$$,
    '42501', null, 'cannot send as someone else');
select throws_ok(
    $$insert into messages (conversation_id, body, created_at) values ('20000000-0000-0000-0000-000000000001', 'from the future', now() + interval '1 day')$$,
    '42501', null, 'cannot choose the message time');
select throws_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', '')$$,
    '23514', null, 'empty messages are rejected');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok(
    $$insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'Saturday works')$$,
    'giver can reply');
select is((select count(*) from messages), 2::bigint, 'giver sees the whole conversation');

-- Inbox and read state --------------------------------------------------------
-- Everything in one transaction shares now(), so space the messages out by hand.
set local role postgres;
update messages set created_at = now() - interval '2 minutes' where body = 'Is Saturday ok?';
update messages set created_at = now() - interval '1 minute' where body = 'Saturday works';

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
    $$select last_body, last_sender_is_me, unread_count from my_chats()$$,
    $$values ('Saturday works', false, 1)$$,
    'requester sees the reply as unread');

select lives_ok($$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$, 'requester marks it read');
select is((select unread_count from my_chats()), 0, 'nothing unread after reading');
select is((select count(*) from conversation_reads), 1::bigint, 'requester sees their own read state');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select results_eq(
    $$select last_body, last_sender_is_me, unread_count from my_chats()$$,
    $$values ('Saturday works', true, 1)$$,
    'giver has not read the first message, and sent the latest one');
select is((select count(*) from conversation_reads), 0::bigint, 'giver cannot see the requester''s read state');
select throws_ok(
    $$insert into conversation_reads (conversation_id, user_id) values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a')$$,
    '42501', null, 'read state is written only through mark_conversation_read');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into messages (conversation_id, body) values ('20000000-0000-0000-0000-000000000001', 'See you then');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is((select unread_count from my_chats()), 2, 'new messages from the other person count as unread');

-- Outsiders -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000e');
select is((select count(*) from my_chats()), 0::bigint, 'outsiders have no chats');
select throws_ok(
    $$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$,
    '42501', null, 'outsiders cannot mark a conversation read');

-- Withdrawing clears the chat -------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select withdraw_request('10000000-0000-0000-0000-000000000001');
set local role postgres;
select is(
    (select count(*) from messages) + (select count(*) from conversation_reads),
    0::bigint,
    'withdrawing a request deletes its messages and read state');

-- Realtime and privileges -----------------------------------------------------
select ok(
    exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'),
    'new messages are broadcast over realtime');

set local role anon;
select throws_ok('select * from my_chats()', '42501', null, 'signed-out users cannot list chats');
select throws_ok(
    $$select mark_conversation_read('20000000-0000-0000-0000-000000000001')$$,
    '42501', null, 'signed-out users cannot mark chats read');

select * from finish();
rollback;
