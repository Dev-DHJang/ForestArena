#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
set -a
. "$ROOT/database/.env.development"
. "${FOREST_ARENA_ADMIN_STATE_DIR:-$HOME/Library/Application Support/ForestArena/admin}/db.env"
set +a
compose() { docker compose --env-file "$ROOT/database/.env.development" -f "$ROOT/database/compose.development.yml" "$@"; }
admin_sql() { compose exec -T -e "PGPASSWORD=$ADMIN_DB_PASSWORD" db psql -Xq --set ON_ERROR_STOP=1 --username "$ADMIN_DB_USER" --dbname "$FOREST_ARENA_DB_NAME" -h 127.0.0.1; }
app_sql() { compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_APP_PASSWORD" db psql -Xq --set ON_ERROR_STOP=1 --username "$FOREST_ARENA_DB_APP_USER" --dbname "$FOREST_ARENA_DB_NAME" -h 127.0.0.1; }
printf '%s\n' 'SELECT player_id FROM app.players LIMIT 1;' 'SELECT profile,revision FROM app.player_profiles LIMIT 1;' 'SELECT * FROM admin.accounts LIMIT 0;' | admin_sql >/dev/null
# EXPLAIN validates privileges without changing any row.
for sql in \
  'EXPLAIN UPDATE app.player_profiles SET revision=revision+1;' \
  "EXPLAIN INSERT INTO admin.audit_log(action,target_id,reason_encrypted) VALUES('test','test','test');"
do printf '%s\n' "$sql" | admin_sql >/dev/null; done
for sql in \
  'SELECT * FROM app.refresh_tokens LIMIT 0;' \
  'DELETE FROM app.players WHERE false;' \
  'UPDATE app.matches SET status=status WHERE false;' \
  'DELETE FROM admin.audit_log WHERE false;' \
  'UPDATE admin.audit_log SET action=action WHERE false;' \
  'DELETE FROM admin.requests WHERE false;' \
  'CREATE TABLE admin.forbidden_test(id int);'
do
  if printf '%s\n' "$sql" | admin_sql >/dev/null 2>&1; then echo "FAIL: 전용계정에 불필요한 권한: $sql" >&2; exit 1; fi
done
if printf '%s\n' 'SELECT * FROM admin.accounts LIMIT 0;' | app_sql >/dev/null 2>&1; then echo 'FAIL: 게임 계정 admin 접근 가능' >&2; exit 1; fi
echo 'verify-admin-db: PASS (전용계정 최소 권한·게임계정 admin 접근 거부)'
