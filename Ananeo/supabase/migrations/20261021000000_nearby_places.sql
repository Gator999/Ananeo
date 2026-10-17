-- Places near a point: donation centers, repair cafés, e-waste drop-offs, and textile bins.
-- Reference data, readable before sign-in like the places table itself. Runs as the caller.

create function public.nearby_places(
    lat double precision,
    lng double precision,
    radius_km double precision default 15,
    only_kind public.place_kind default null,
    max_results integer default 100
)
returns table (
    id uuid,
    kind public.place_kind,
    name text,
    address text,
    latitude double precision,
    longitude double precision,
    accepts public.item_category[],
    hours text,
    website text,
    verified boolean,
    distance_km double precision
)
language sql
stable
set search_path = ''
as $$
    with origin as (
        select extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography as g
    )
    select
        p.id, p.kind, p.name, p.address,
        extensions.st_y(p.location::extensions.geometry),
        extensions.st_x(p.location::extensions.geometry),
        p.accepts, p.hours, p.website, p.verified,
        extensions.st_distance(p.location, origin.g) / 1000
    from public.places p, origin
    where extensions.st_dwithin(p.location, origin.g, least(radius_km, 100) * 1000)
      and (only_kind is null or p.kind = only_kind)
    order by extensions.st_distance(p.location, origin.g)
    limit least(max_results, 200);
$$;

-- New functions are executable by everyone by default, so start from nothing.
revoke execute on function public.nearby_places(double precision, double precision, double precision, public.place_kind, integer) from public, anon, authenticated;
grant execute on function public.nearby_places(double precision, double precision, double precision, public.place_kind, integer) to anon, authenticated;
