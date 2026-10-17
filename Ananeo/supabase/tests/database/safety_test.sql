-- Blocking, reporting, and moderation.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(41);

-- Users -----------------------------------------------------------------------
-- Alice gives and misbehaves. Bob and Carol ask for things and report. Dana moderates. Erin reports.
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}'),
    ('00000000-0000-0000-0000-00000000000c', 'carol@test.local', 'authenticated', 'authenticated', '{"full_name":"Carol"}'),
    ('00000000-0000-0000-0000-00000000000d', 'dana@test.local',  'authenticated', 'authenticated', '{"full_name":"Dana"}'),
    ('00000000-0000-0000-0000-00000000000e', 'erin@test.local',  'authenticated', 'authenticated', '{"full_name":"Erin"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into items (id, title, category, location) values
    ('10000000-0000-0000-0000-000000000001', 'Oak bookshelf', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)'),
    ('10000000-0000-0000-0000-000000000002', 'Desk lamp', 'household', 'SRID=4326;POINT(-73.9442 40.6782)'),
    ('10000000-0000-0000-0000-000000000003', 'Kitchen chair', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)'),
    ('10000000-0000-0000-0000-000000000004', 'Writing desk', 'furniture', 'SRID=4326;POINT(-73.9442 40.6782)'),
    ('10000000-0000-0000-0000-000000000006', 'Wool rug', 'household', 'SRID=4326;POINT(-73.9442 40.6782)');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into items (id, title, category, location) values
    ('10000000-0000-0000-0000-000000000007', 'Kettle', 'household', 'SRID=4326;POINT(-73.9442 40.6782)');

-- Blocking ends pickups in progress ------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (id, item_id, giver_id)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
do $$ begin perform public.reserve_item('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b'); end $$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select lives_ok($$insert into blocks (blocked_id) values ('00000000-0000-0000-0000-00000000000a')$$, 'the receiver blocks the giver');
select is((select blocker_id from blocks), '00000000-0000-0000-0000-00000000000b'::uuid, 'the blocker defaults to the caller');

set local role postgres;
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000001'), 'available', 'blocking puts a reserved item back');
select is((select count(*) from handoffs where item_id = '10000000-0000-0000-0000-000000000001'), 0::bigint, 'blocking ends the pending handoff');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
    $$insert into blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000a')$$,
    '42501', null, 'nobody can block on someone else''s behalf');
delete from blocks where blocked_id = '00000000-0000-0000-0000-00000000000a';
select is(is_blocked('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'), false, 'unblocking works');

-- A completed handoff survives a block.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
do $$ begin perform public.reserve_item('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-00000000000c'); end $$;
do $$ begin perform public.confirm_handoff((select id from public.handoffs where item_id = '10000000-0000-0000-0000-000000000004')); end $$;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
do $$ begin perform public.confirm_handoff((select id from public.handoffs where item_id = '10000000-0000-0000-0000-000000000004')); end $$;
insert into blocks (blocked_id) values ('00000000-0000-0000-0000-00000000000a');
set local role postgres;
select isnt((select completed_at from handoffs where item_id = '10000000-0000-0000-0000-000000000004'), null, 'a completed handoff survives a block');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
delete from blocks where blocked_id = '00000000-0000-0000-0000-00000000000a';

-- Reports ---------------------------------------------------------------------
select lives_ok(
    $$insert into reports (target_type, target_id, reason) values ('item', '10000000-0000-0000-0000-000000000002', 'Prohibited item')$$,
    'someone reports a listing');
select throws_ok(
    $$insert into reports (target_type, target_id, reason) values ('item', '10000000-0000-0000-0000-000000000002', 'Prohibited item')$$,
    '23505', null, 'reporting the same thing twice is refused');
select throws_ok(
    $$insert into reports (target_type, target_id, reason) values ('item', '10000000-0000-0000-0000-000000000007', 'Other')$$,
    '42501', null, 'nobody can report their own listing');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
update items set status = 'removed' where id = '10000000-0000-0000-0000-000000000003';
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
    $$insert into reports (target_type, target_id, reason) values ('item', '10000000-0000-0000-0000-000000000003', 'Other')$$,
    '42501', null, 'a listing you can''t see can''t be reported');

-- Alice's message, written directly so the test knows its ID. Clients can't choose message IDs.
set local role postgres;
insert into messages (id, conversation_id, sender_id, body)
values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'Get lost');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
    $$insert into reports (target_type, target_id, reason) values ('message', '30000000-0000-0000-0000-000000000001', 'Harassment or hate')$$,
    '42501', null, 'a message in someone else''s chat can''t be reported');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select lives_ok(
    $$insert into reports (target_type, target_id, reason) values ('message', '30000000-0000-0000-0000-000000000001', 'Harassment or hate')$$,
    'the recipient reports a message');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
    $$insert into reports (target_type, target_id, reason) values ('user', '00000000-0000-0000-0000-00000000000c', 'Other')$$,
    '42501', null, 'nobody can report themselves');
select lives_ok(
    $$insert into reports (target_type, target_id, reason) values ('user', '00000000-0000-0000-0000-00000000000a', 'Safety concern: did not show up twice')$$,
    'someone reports a person');
select throws_ok(
    $$insert into reports (target_type, target_id, reason, status) values ('user', '00000000-0000-0000-0000-00000000000b', 'Other', 'actioned')$$,
    '42501', null, 'reporters cannot set the status');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000e');
select lives_ok(
    $$insert into reports (target_type, target_id, reason) values ('item', '10000000-0000-0000-0000-000000000002', 'Spam or scam')$$,
    'a second person reports the same listing');

-- Only moderators moderate ----------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is(is_moderator(), false, 'ordinary users are not moderators');
select is((select count(*) from moderation_queue()), 0::bigint, 'ordinary users see an empty queue');
select throws_ok(
    $$select moderate('item', '10000000-0000-0000-0000-000000000002', 'remove')$$,
    '42501', null, 'ordinary users cannot moderate');
select throws_ok('select count(*) from moderators', '42501', null, 'the moderator list is private');

set local role postgres;
insert into moderators (user_id) values ('00000000-0000-0000-0000-00000000000d');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is(is_moderator(), true, 'moderators are recognized');
select set_eq(
    $$select target_type::text, subject_name, summary, report_count from moderation_queue()$$,
    $$values ('item', 'Alice', 'Desk lamp', 2::bigint),
             ('message', 'Alice', 'Get lost', 1::bigint),
             ('user', 'Alice', 'Alice', 1::bigint)$$,
    'the queue groups open reports by what was reported');
select is(
    (select cardinality(reasons) from moderation_queue() where target_type = 'item'), 2,
    'every reason is listed');

-- Removing a message ----------------------------------------------------------
select lives_ok($$select moderate('message', '30000000-0000-0000-0000-000000000001', 'remove')$$, 'a moderator removes a message');
set local role postgres;
select is((select count(*) from messages where id = '30000000-0000-0000-0000-000000000001'), 0::bigint, 'the message is deleted');
select is((select status::text from reports where target_type = 'message'), 'actioned', 'its reports are marked actioned');

-- Dismissing ------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select lives_ok($$select moderate('item', '10000000-0000-0000-0000-000000000002', 'dismiss')$$, 'a moderator dismisses reports on a listing');
set local role postgres;
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000002'), 'available', 'a dismissed listing stays up');
select is(
    (select array_agg(distinct status::text) from reports where target_type = 'item'), array['dismissed'],
    'its reports are marked dismissed');

-- Banning ---------------------------------------------------------------------
-- Alice has the rug reserved for Bob, and Carol's kettle reserved for her.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-00000000000a');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
do $$ begin perform public.reserve_item('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-00000000000b'); end $$;
insert into conversations (item_id, giver_id) values ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-00000000000c');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
do $$ begin perform public.reserve_item('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-00000000000a'); end $$;
set local role postgres;
insert into auth.sessions (id, user_id) values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000a');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select lives_ok($$select moderate('user', '00000000-0000-0000-0000-00000000000a', 'ban')$$, 'a moderator bans a person');

set local role postgres;
select isnt((select banned_at from profiles where id = '00000000-0000-0000-0000-00000000000a'), null, 'the profile is marked banned');
select ok(
    (select banned_until > now() + interval '99 years' from auth.users where id = '00000000-0000-0000-0000-00000000000a'),
    'sign-in is refused for good');
select is((select count(*) from auth.sessions where user_id = '00000000-0000-0000-0000-00000000000a'), 0::bigint, 'their sessions are revoked');
select is(
    (select count(*) from items where owner_id = '00000000-0000-0000-0000-00000000000a' and status in ('available', 'reserved')), 0::bigint,
    'their open listings come down');
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000007'), 'available', 'items reserved for them go back on the feed');
select is(
    (select count(*) from handoffs where completed_at is null and '00000000-0000-0000-0000-00000000000a' in (giver_id, receiver_id)), 0::bigint,
    'pickups in progress with them end');
select is((select status::text from items where id = '10000000-0000-0000-0000-000000000004'), 'handed_off', 'completed handoffs are untouched');
select is((select status::text from reports where target_type = 'user'), 'actioned', 'reports on them are marked actioned');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is((select count(*) from moderation_queue()), 0::bigint, 'the queue is empty once everything is resolved');

-- Privileges ------------------------------------------------------------------
set local role postgres;
set local role anon;
select throws_ok('select is_moderator()', '42501', null, 'signed-out users cannot check moderator status');

select * from finish();
rollback;
