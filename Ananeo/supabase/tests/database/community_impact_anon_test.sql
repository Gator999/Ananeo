-- Everyone's totals are readable before sign-in. Nothing else is.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(4);

set local role anon;
select lives_ok($$select * from community_impact()$$, 'signed-out users can read the community totals');
select results_eq(
    $$select items_kept_moving, kg_diverted from community_impact()$$,
    $$values (0::bigint, 0::numeric)$$,
    'an empty database reports zero, not nothing');
select throws_ok($$select * from my_impact()$$, '42501', null, 'signed-out users still cannot read personal impact');
select throws_ok($$select * from nearby_items(40.6782, -73.9442, 5)$$, '42501', null, 'signed-out users still cannot browse');

select * from finish();
rollback;
