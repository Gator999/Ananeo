-- Local development data, loaded by `supabase db reset`. Never applied to the hosted project.
-- Sample places around the same point the database tests use, so the Places map has pins when the
-- simulator's location is set to Brooklyn. Replace with the launch city once it is chosen.

insert into public.places (kind, name, address, location, accepts, hours, verified) values
    ('donation', 'Community Thrift', '120 Main St', 'SRID=4326;POINT(-73.9440 40.6790)', '{clothing,books,household}', 'Mon–Sat 10–6', true),
    ('donation', 'Habitat ReStore', '48 Industrial Rd', 'SRID=4326;POINT(-73.9620 40.6900)', '{furniture,tools,household,materials}', 'Wed–Sun 10–5', true),
    ('repair', 'Fix-It Café', '5 Repair Row', 'SRID=4326;POINT(-73.9500 40.6820)', '{electronics,tools,household}', 'Second Saturday, 12–4', false),
    ('ewaste', 'E-Waste Depot', '900 Recycling Way', 'SRID=4326;POINT(-73.9300 40.6700)', '{electronics}', 'Tue–Sat 9–4', true),
    ('textile', 'Textile Drop Bin', 'Corner of Park and 5th', 'SRID=4326;POINT(-73.9400 40.6730)', '{clothing}', 'Always open', false)
on conflict do nothing;
