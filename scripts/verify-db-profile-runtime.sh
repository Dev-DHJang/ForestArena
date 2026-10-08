#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
[ -f database/.env.development ] || { echo '먼저 ./scripts/server-dev.sh up을 실행하세요.' >&2; exit 1; }
set -a
. "$ROOT/database/.env.development"
set +a
export FOREST_ARENA_API_URL="http://127.0.0.1:$FOREST_ARENA_API_PORT"
export DATABASE_URL="postgresql://$FOREST_ARENA_DB_APP_USER:$FOREST_ARENA_DB_APP_PASSWORD@127.0.0.1:$FOREST_ARENA_DB_PORT/$FOREST_ARENA_DB_NAME"
export FOREST_ARENA_PROFILE_RUN_ID="$(date +%s)-$$"
export FOREST_ARENA_PROFILE_REPORT="/private/tmp/forest-db-profile-$FOREST_ARENA_PROFILE_RUN_ID.json"
godot --headless --path . --script res://tools/forest_arena/profile_catalog.gd
npm --prefix server/api run build
godot --headless --path . --script res://tests/db_profile_runtime.gd
godot --headless --path . --script res://tests/db_profile_runtime.gd -- --restore
node server/api/dist/tests/profile_runtime.js
echo 'verify-db-profile-runtime: PASS'
