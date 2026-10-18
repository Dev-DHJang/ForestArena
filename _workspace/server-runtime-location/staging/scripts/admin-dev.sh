#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE_DIR="$ROOT/admin"
PID_FILE="$STATE_DIR/server.pid"
JAR="$STATE_DIR/running-admin.jar"
running() {
  [ -f "$PID_FILE" ] || return 1
  admin_pid=$(sed -n '1p' "$PID_FILE")
  case "$admin_pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$admin_pid" 2>/dev/null || return 1
  ps -p "$admin_pid" -o command= | grep -F -- "$JAR" >/dev/null
}
case ${1:-} in
  start)
    running && { echo 'admin-dev: 이미 실행 중입니다.' >&2; exit 1; }
    [ -f "$JAR" ] && [ -f "$STATE_DIR/db.env" ] && [ -f "$STATE_DIR/keys.json" ] || { echo 'admin-dev: 실행 파일·환경·키가 필요합니다.' >&2; exit 1; }
    set -a
    . "$STATE_DIR/db.env"
    set +a
    export ADMIN_KEY_FILE="$STATE_DIR/keys.json"
    export GAME_API_URL=http://127.0.0.1:3000
    if [ -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]; then
      JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home; export JAVA_HOME
      PATH="$JAVA_HOME/bin:$PATH"; export PATH
    fi
    umask 077
    python3 - "$STATE_DIR" <<'PY'
import pathlib, subprocess, sys
state = pathlib.Path(sys.argv[1])
with (state / 'server.log').open('ab') as log:
    process = subprocess.Popen(['java', '-jar', str(state / 'running-admin.jar')], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
(state / 'server.pid').write_text(str(process.pid) + '\n')
PY
    echo 'admin-dev: 새 운영 폴더에서 시작했습니다.'
    ;;
  stop)
    running || { echo 'admin-dev: 이 폴더에서 실행 중인 프로세스가 없습니다.' >&2; exit 1; }
    kill "$admin_pid"
    ;;
  status)
    running || { echo 'admin-dev: 중지됨'; exit 1; }
    curl --fail --silent --output /dev/null http://127.0.0.1:8080/admin/api/v1/auth/csrf
    echo 'admin-dev: 준비됨 http://127.0.0.1:8080'
    ;;
  logs) tail -f "$STATE_DIR/server.log" ;;
  *) echo '사용법: ./scripts/admin-dev.sh start|stop|status|logs' >&2; exit 1 ;;
esac
