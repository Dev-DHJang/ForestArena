#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE_DIR=${FOREST_ARENA_ADMIN_STATE_DIR:-"$HOME/Library/Application Support/ForestArena/admin"}
ENV_FILE="$STATE_DIR/db.env"
PID_FILE="$STATE_DIR/server.pid"
fail() { echo "admin-dev: $*" >&2; exit 1; }
java_setup() {
  if [ -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]; then
    JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home; export JAVA_HOME
    PATH="$JAVA_HOME/bin:$PATH"; export PATH
  fi
  java -version 2>&1 | head -n 1
}
load_env() {
  [ -f "$ENV_FILE" ] || fail '먼저 setup을 실행하세요.'
  set -a
  . "$ENV_FILE"
  set +a
  ADMIN_KEY_FILE="$STATE_DIR/keys.json"; export ADMIN_KEY_FILE
  GAME_API_URL=${GAME_API_URL:-http://127.0.0.1:3000}; export GAME_API_URL
}
build() {
  java_setup
  (cd "$ROOT/web/admin" && npm ci && npm run build)
  (cd "$ROOT/server/admin" && ./mvnw -q -DskipTests package)
  mkdir -p "$ROOT/server/admin/target/classes/static"
  cp -R "$ROOT/web/admin/dist/." "$ROOT/server/admin/target/classes/static/"
  (cd "$ROOT/server/admin" && ./mvnw -q -DskipTests package)
}
jar_path() {
  find "$ROOT/server/admin/target" -maxdepth 1 -name '*.jar' ! -name '*.original' | head -n 1
}
case ${1:-} in
  setup)
    [ -f "$ROOT/database/.env.development" ] || fail '먼저 ./scripts/db-dev.sh up을 실행하세요.'
    "$ROOT/scripts/db-dev.sh" migrate
    umask 077
    mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
    if [ ! -f "$ENV_FILE" ]; then
      admin_web_password=$(openssl rand -hex 32)
      {
        printf '%s\n' 'ADMIN_DB_USER=forest_arena_admin_web'
        printf 'ADMIN_DB_PASSWORD=%s\n' "$admin_web_password"
        printf '%s\n' 'ADMIN_DB_URL=jdbc:postgresql://127.0.0.1:55432/forest_arena_dev'
      } > "$ENV_FILE"
    fi
    chmod 600 "$ENV_FILE"
    set -a
    . "$ROOT/database/.env.development"
    . "$ENV_FILE"
    set +a
    # Values are delivered through stdin to psql, never command arguments or logs.
    printf "ALTER ROLE forest_arena_admin_web PASSWORD '%s';\n" "$ADMIN_DB_PASSWORD" |
      docker compose --env-file "$ROOT/database/.env.development" -f "$ROOT/database/compose.development.yml" exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db psql -q --set ON_ERROR_STOP=1 --username "$FOREST_ARENA_DB_ADMIN_USER" --dbname "$FOREST_ARENA_DB_NAME"
    echo 'admin-dev: 전용 DB 계정 준비 완료. build 뒤 bootstrap으로 최초 계정을 만드세요.'
    ;;
  build) build ;;
  start)
    load_env; java_setup
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then fail '이미 실행 중입니다.'; fi
    jar=$(jar_path); [ -n "$jar" ] || fail '먼저 build를 실행하세요.'
    umask 077
    cp "$jar" "$STATE_DIR/running-admin.jar"
    python3 - "$STATE_DIR" "$PID_FILE" <<'PYTHON'
import pathlib, subprocess, sys
state = pathlib.Path(sys.argv[1])
with (state / "server.log").open("ab") as log:
    process = subprocess.Popen(
        ["java", "-jar", str(state / "running-admin.jar")],
        stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
pathlib.Path(sys.argv[2]).write_text(str(process.pid) + "\n")
PYTHON
    echo 'admin-dev: 시작 요청 완료. status로 준비 상태를 확인하세요.'
    ;;
  stop)
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi
    echo 'admin-dev: 중지 완료.'
    ;;
  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      curl --fail --silent http://127.0.0.1:8080/admin/api/v1/auth/csrf >/dev/null && echo 'admin-dev: 준비됨 http://127.0.0.1:8080' || echo 'admin-dev: 프로세스 실행 중, 준비 대기'
    else echo 'admin-dev: 중지됨'; fi
    ;;
  bootstrap|recover|key-init|rotate-key)
    load_env; java_setup
    jar=$(jar_path); [ -n "$jar" ] || fail '먼저 build를 실행하세요.'
    action=$1; shift
    [ "$action" != rotate-key ] || action=key-rotate
    exec java -jar "$jar" "$action" "$@"
    ;;
  *) echo '사용법: ./scripts/admin-dev.sh setup|build|start|stop|status|key-init|bootstrap <ID> <이름>|recover <ID>|rotate-key' ;;
esac
