-- Terms of use acceptance.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(11);

insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', 'authenticated', 'authenticated', '{"full_name":"Alice"}'),
    ('00000000-0000-0000-0000-00000000000b', 'bob@test.local',   'authenticated', 'authenticated', '{"full_name":"Bob"}');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is(my_terms_version(), 0, 'a new account has accepted nothing');
select lives_ok('select accept_terms(1)', 'accepting the terms');
select is(my_terms_version(), 1, 'the accepted version is recorded');
select lives_ok('select accept_terms(1)', 'accepting the same version again is harmless');
select lives_ok('select accept_terms(2)', 'accepting a newer version');
select is(my_terms_version(), 2, 'the newest accepted version counts');
select throws_ok('select accept_terms(0)', '23514', null, 'versions start at 1');
select throws_ok(
    $$insert into terms_acceptances (user_id, version) values ('00000000-0000-0000-0000-00000000000a', 3)$$,
    '42501', null, 'acceptances are written only through accept_terms');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select is((select count(*) from terms_acceptances), 0::bigint, 'nobody can see anyone else''s acceptances');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select delete_account();
set local role postgres;
select is((select count(*) from terms_acceptances), 0::bigint, 'deleting an account deletes its acceptances');

set local role anon;
select throws_ok('select accept_terms(1)', '42501', null, 'signed-out users cannot accept terms');

select * from finish();
rollback;
