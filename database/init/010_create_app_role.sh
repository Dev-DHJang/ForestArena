#!/bin/sh
set -eu

: "${FOREST_ARENA_DB_APP_USER:?FOREST_ARENA_DB_APP_USER is required}"
: "${FOREST_ARENA_DB_APP_PASSWORD:?FOREST_ARENA_DB_APP_PASSWORD is required}"

psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 \
  --set app_user="$FOREST_ARENA_DB_APP_USER" \
  --set app_password="$FOREST_ARENA_DB_APP_PASSWORD" <<'SQL'
SELECT format(
  'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
  :'app_user',
  :'app_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'app_user'
) \gexec
SQL
