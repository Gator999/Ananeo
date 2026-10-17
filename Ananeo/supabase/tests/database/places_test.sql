-- Places near a point, for the Places map.
-- Run with: supabase test db
begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(7);

-- seed.sql adds sample places on `supabase start`; this test wants only its own rows. Rolled back with the rest.
delete from public.places;

-- Three places in Brooklyn and one in Manhattan, about 7 km away.
insert into places (id, kind, name, address, location, accepts) values
    ('20000000-0000-0000-0000-000000000001', 'donation', 'Community Thrift', '120 Main St', 'SRID=4326;POINT(-73.9440 40.6790)', '{clothing,books,household}'),
    ('20000000-0000-0000-0000-000000000002', 'repair', 'Fix-It Café', '5 Repair Row', 'SRID=4326;POINT(-73.9500 40.6820)', '{electronics,tools}'),
    ('20000000-0000-0000-0000-000000000003', 'ewaste', 'E-Waste Depot', '900 Recycling Way', 'SRID=4326;POINT(-73.9300 40.6700)', '{electronics}'),
    ('20000000-0000-0000-0000-000000000004', 'textile', 'Midtown Textile Bin', '1 Far Ave', 'SRID=4326;POINT(-73.9855 40.7580)', '{clothing}');

set local role anon;
select results_eq(
    $$select name from nearby_places(40.6782, -73.9442, 5)$$,
    $$values ('Community Thrift'), ('Fix-It Café'), ('E-Waste Depot')$$,
    'places within the radius come back closest first');
select ok((select distance_km from nearby_places(40.6782, -73.9442, 5) limit 1) < 0.2, 'distance is reported in km');
select results_eq(
    $$select round(latitude::numeric, 4), round(longitude::numeric, 4) from nearby_places(40.6782, -73.9442, 0.5)$$,
    $$values (40.6790::numeric, -73.9440::numeric)$$,
    'latitude and longitude come back for the pin');
select is((select count(*) from nearby_places(40.6782, -73.9442, 5, 'repair')), 1::bigint, 'kind filter applies');
select is((select count(*) from nearby_places(40.6782, -73.9442, 50)), 4::bigint, 'a wider radius reaches Manhattan');
select is((select count(*) from nearby_places(40.6782, -73.9442, 5, null, 2)), 2::bigint, 'max_results caps the list');

set local role postgres;
set local role authenticated;
select lives_ok($$select * from nearby_places(40.6782, -73.9442, 5)$$, 'signed-in users can read places too');

select * from finish();
rollback;
