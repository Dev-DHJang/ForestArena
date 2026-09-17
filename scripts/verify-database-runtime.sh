#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT/database/.env.development"
COMPOSE_FILE="$ROOT/database/compose.development.yml"

fail() {
  echo "verify-database-runtime: FAIL: $*" >&2
  exit 1
}

"$ROOT/scripts/db-dev.sh" up >/dev/null

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

admin_psql() {
  compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db \
    psql --username "$FOREST_ARENA_DB_ADMIN_USER" --dbname "$FOREST_ARENA_DB_NAME" "$@"
}

app_psql() {
  compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_APP_PASSWORD" db \
    psql --username "$FOREST_ARENA_DB_APP_USER" --dbname "$FOREST_ARENA_DB_NAME" "$@"
}

cleanup() {
  admin_psql --set ON_ERROR_STOP=1 -c 'DROP TABLE IF EXISTS app.database_runtime_verification' >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

[ "$(admin_psql -Atqc "SELECT environment_name FROM infra.environment_guard WHERE singleton")" = "development" ] \
  || fail "개발계 표식이 없습니다."

"$ROOT/scripts/db-dev.sh" migrate >/dev/null

admin_psql --set ON_ERROR_STOP=1 -c \
  'CREATE TABLE app.database_runtime_verification (id integer PRIMARY KEY, note text NOT NULL)' >/dev/null
app_psql --set ON_ERROR_STOP=1 -c \
  "INSERT INTO app.database_runtime_verification (id, note) VALUES (1, 'runtime verification')" >/dev/null
[ "$(app_psql -Atqc 'SELECT count(*) FROM app.database_runtime_verification')" = "1" ] \
  || fail "앱 계정이 app 스키마 데이터를 읽고 쓰지 못합니다."

if app_psql --set ON_ERROR_STOP=1 -c 'CREATE TABLE app.database_runtime_forbidden (id integer)' >/dev/null 2>&1; then
  fail "앱 계정이 표를 만들 수 있습니다."
fi

echo "verify-database-runtime: PASS"
echo "- 개발계 표식, 반복 마이그레이션, 앱 데이터 권한과 DDL 거부 확인"
