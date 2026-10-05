#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT/database/.env.development"
COMPOSE_FILE="$ROOT/database/compose.development.yml"

fail() {
  echo "server-dev: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
사용법: ./scripts/server-dev.sh <명령>

명령:
  up       PostgreSQL, API와 Godot 게임 서버를 빌드하고 시작한다.
  down     로컬 서버와 DB 컨테이너를 멈춘다. DB 볼륨은 유지한다.
  status   세 서비스의 상태를 표시한다.
  logs     API와 게임 서버 로그를 계속 표시한다.
  test     서버 계약과 TypeScript 단위 검사를 실행한다.
  verify-runtime
           실행 중인 로컬 스택에서 2인 매칭·재접속·결과 저장을 검증한다.
USAGE
}

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

case ${1:-} in
  up)
    "$ROOT/scripts/db-dev.sh" up
    compose up --detach --build --wait api game-server
    echo "server-dev: API http://127.0.0.1:$(. "$ENV_FILE"; printf '%s' "$FOREST_ARENA_API_PORT")"
    echo "server-dev: Game ws://127.0.0.1:$(. "$ENV_FILE"; printf '%s' "$FOREST_ARENA_GAME_PORT")"
    ;;
  down)
    [ -f "$ENV_FILE" ] || fail "환경 파일이 없습니다."
    compose down
    ;;
  status)
    [ -f "$ENV_FILE" ] || fail "환경 파일이 없습니다."
    compose ps
    ;;
  logs)
    [ -f "$ENV_FILE" ] || fail "환경 파일이 없습니다."
    compose logs --follow api game-server
    ;;
  test)
    "$ROOT/scripts/verify-online-server.sh"
    ;;
  verify-runtime)
    [ -f "$ENV_FILE" ] || fail "환경 파일이 없습니다."
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
    runtime_status=0
    compose run --rm --no-deps \
      -e FOREST_ARENA_RUNTIME_API_URL=http://forest-arena-api:3000 \
      -e FOREST_ARENA_RUNTIME_WS_URL=ws://game-server:7777 \
      game-server godot --headless --path /game res://server/game/runtime_verifier.tscn || runtime_status=$?
    compose restart api game-server >/dev/null
    compose up --detach --wait api game-server >/dev/null
    [ "$runtime_status" -eq 0 ] || exit "$runtime_status"
    echo "server-dev: 온라인 런타임 검증을 통과했습니다."
    ;;
  *)
    usage
    exit 1
    ;;
esac
