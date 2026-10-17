#!/bin/bash
# Runs the pgTAP tests against the Supabase Postgres image alone, for machines where the Supabase
# CLI can't be installed (cloud containers that block GitHub release downloads). Needs Docker.
# `supabase test db` is still the normal way to run them.
#
# Usage: scripts/db-test-docker.sh [image tag]
set -euo pipefail
cd "$(dirname "$0")/../supabase"

TAG="${1:-17.11.0.004}"
NAME=ananeo-db-test
PORT=54329
export PGPASSWORD=postgres
DB="postgresql://postgres@127.0.0.1:$PORT/postgres"
ADMIN="postgresql://supabase_admin@127.0.0.1:$PORT/postgres"

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=postgres -p "$PORT:5432" "supabase/postgres:$TAG" >/dev/null
for _ in $(seq 1 60); do
  psql "$DB" -c "select 1" >/dev/null 2>&1 && break
  sleep 2
done

# The bare image ships an older auth.uid() that ignores request.jwt.claims, and no storage tables.
# The CLI stack adds both, so add them here as the superuser before the migrations run.
psql "$ADMIN" -v ON_ERROR_STOP=1 -q <<'SQL'
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;
create table if not exists storage.buckets (
  id text primary key, name text not null, owner uuid, public boolean default false,
  file_size_limit bigint, allowed_mime_types text[],
  created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets (id),
  name text, owner uuid, metadata jsonb, created_at timestamptz default now(), updated_at timestamptz default now(),
  path_tokens text[] generated always as (string_to_array(name, '/')) stored);
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[] language plpgsql as $$
declare _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end
$$;
grant usage on schema storage to anon, authenticated;
grant all on storage.objects, storage.buckets to anon, authenticated;
SQL

for m in migrations/*.sql; do
  psql "$DB" -v ON_ERROR_STOP=1 -q -f "$m"
done

failed=0
for t in tests/database/*.sql; do
  out=$(psql "$DB" -Atq -f "$t" 2>&1)
  bad=$(echo "$out" | grep -cE '^not ok|ERROR' || true)
  printf '%-45s %s passed, %s failed\n' "$t" "$(echo "$out" | grep -cE '^ok ' || true)" "$bad"
  if [ "$bad" != "0" ]; then
    echo "$out" | grep -E '^not ok|ERROR|^# ' | head -20
    failed=1
  fi
done

docker rm -f "$NAME" >/dev/null
exit $failed
