#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compose() {
  docker compose --env-file "$ROOT/database/.env.development" -f "$ROOT/database/compose.development.yml" "$@"
}
case ${1:-} in
  up)
    for pair in 'forest-arena-development-api api' 'forest-arena-development-game-server game-server' 'postgres:18.6-alpine3.23 postgres'; do
      set -- $pair
      docker image inspect "$1" >/dev/null 2>&1 || docker load --input "$ROOT/images/$2.tar"
    done
    compose up --detach --no-build --wait db api game-server
    ;;
  down) compose down ;;
  status) compose ps ;;
  logs) compose logs --follow api game-server ;;
  *) echo '사용법: ./scripts/server-dev.sh up|down|status|logs' >&2; exit 1 ;;
esac
