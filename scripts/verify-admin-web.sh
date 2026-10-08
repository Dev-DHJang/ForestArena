#!/bin/sh
set -eu
umask 077
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE_DIR=${FOREST_ARENA_ADMIN_STATE_DIR:-"$HOME/Library/Application Support/ForestArena/admin"}
[ -f "$STATE_DIR/test.env" ] || { echo '먼저 python3 scripts/prepare-admin-test-db.py 실행'; exit 1; }
set -a
. "$STATE_DIR/test.env"
set +a
case "$ADMIN_TEST_DATABASE_URL" in */forest_arena_admin_test_dev) ;; *) echo '전용 테스트 DB만 허용'; exit 1;; esac
if [ -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]; then
 JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home; export JAVA_HOME
 PATH="$JAVA_HOME/bin:$PATH"; export PATH
fi
(cd "$ROOT/server/admin" && ./mvnw -q test)
(cd "$ROOT/server/api" && npm ci && npm test)
(cd "$ROOT/web/admin" && npm ci && npm run build)
mkdir -p "$ROOT/server/admin/target/classes/static"
cp -R "$ROOT/web/admin/dist/." "$ROOT/server/admin/target/classes/static/"
(cd "$ROOT/server/admin" && ./mvnw -q -DskipTests package)
export ADMIN_E2E_FIXTURE_FILE="$STATE_DIR/e2e.env"
(cd "$ROOT/server/admin" && ./mvnw -q -Dtest=E2eFixtureTest test)
set -a
. "$STATE_DIR/e2e.env"
set +a
# A separate port avoids stopping the user's administrator process.
export ADMIN_BROWSER_URL=http://127.0.0.1:18080
cp "$ROOT/server/admin/target/admin-0.1.0.jar" "$STATE_DIR/browser-admin.jar"
java -jar "$STATE_DIR/browser-admin.jar" --server.port=18080 > "$STATE_DIR/browser-server.log" 2>&1 &
admin_test_pid=$!
trap 'kill "$admin_test_pid" 2>/dev/null || true' EXIT HUP INT TERM
ready=false
for attempt in $(seq 1 30); do
 if curl --fail --silent "$ADMIN_BROWSER_URL/admin/api/v1/auth/csrf" > /dev/null; then ready=true; break; fi
 sleep 1
done
[ "$ready" = true ] || { echo '브라우저 검사 서버 시작 실패'; exit 1; }
(cd "$ROOT/web/admin" && npm run test:browser)
"$ROOT/scripts/verify-admin-db.sh"
echo 'verify-admin-web: PASS (PostgreSQL·보안·프로필·실제 Spring 브라우저 전체 흐름)'
