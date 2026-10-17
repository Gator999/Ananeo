-- What the website at ananeo.app needs beyond the iOS app.
-- The landing page shows the community total before anyone signs in, and the Donate page lists
-- places by distance the same way Browse lists items.

-- ---------------------------------------------------------------------------
-- Community totals are aggregates only (no row-level data leaves the function), so the signed-out
-- landing page may read them.
-- ---------------------------------------------------------------------------

grant execute on function public.community_impact() to anon;

-- ---------------------------------------------------------------------------
-- Places near a point, closest first. Places are public reference data already readable by anon,
-- so this only adds the distance and the ordering.
-- ---------------------------------------------------------------------------

create function public.nearby_places(
    lat double precision,
    lng double precision,
    radius_km double precision default 25,
    only_kind public.place_kind default null,
    max_results integer default 50
)
returns table (
    id uuid,
    kind public.place_kind,
    name text,
    address text,
    accepts public.item_category[],
    hours text,
    website text,
    verified boolean,
    latitude double precision,
    longitude double precision,
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
        p.id, p.kind, p.name, p.address, p.accepts, p.hours, p.website, p.verified,
        extensions.st_y(p.location::extensions.geometry),
        extensions.st_x(p.location::extensions.geometry),
        extensions.st_distance(p.location, origin.g) / 1000
    from public.places p, origin
    where extensions.st_dwithin(p.location, origin.g, least(radius_km, 200) * 1000)
      and (only_kind is null or p.kind = only_kind)
    order by extensions.st_distance(p.location, origin.g)
    limit least(max_results, 200);
$$;

-- New functions are executable by everyone by default, so start from nothing.
revoke execute on function public.nearby_places(double precision, double precision, double precision, public.place_kind, integer) from public, anon, authenticated;
grant execute on function public.nearby_places(double precision, double precision, double precision, public.place_kind, integer) to anon, authenticated;
