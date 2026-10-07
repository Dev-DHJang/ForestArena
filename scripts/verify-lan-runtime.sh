#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PORT=${FOREST_ARENA_LAN_TEST_PORT:-17777}
LOG_FILE=$(mktemp /tmp/forest-arena-lan-server-XXXXXX)
RUNTIME_LOG=$(mktemp /tmp/forest-arena-lan-runtime-XXXXXX)
APP_LOG=$(mktemp /tmp/forest-arena-lan-app-XXXXXX)
server_pid=""

cleanup() {
  if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

FOREST_ARENA_LAN_BIND_HOST=127.0.0.1 \
FOREST_ARENA_LAN_ADVERTISED_WS_URL="ws://127.0.0.1:$PORT" \
FOREST_ARENA_LAN_PORT="$PORT" \
  godot --headless --path "$ROOT" res://server/game/lan_game_server.tscn >"$LOG_FILE" 2>&1 &
server_pid=$!

attempts=0
while [ "$attempts" -lt 50 ]; do
  grep -q 'FOREST_ARENA_LAN_READY' "$LOG_FILE" && break
  kill -0 "$server_pid" 2>/dev/null || { tail -50 "$LOG_FILE"; exit 1; }
  sleep 0.1
  attempts=$((attempts + 1))
done
grep -q 'FOREST_ARENA_LAN_READY' "$LOG_FILE" || { tail -50 "$LOG_FILE"; exit 1; }

FOREST_ARENA_LAN_TEST_WS_URL="ws://127.0.0.1:$PORT" \
  godot --headless --path "$ROOT" res://tests/lan_runtime_verifier.tscn >"$RUNTIME_LOG" 2>&1 || { cat "$RUNTIME_LOG"; exit 1; }
cat "$RUNTIME_LOG"
if rg -n 'SCRIPT ERROR|ERROR:' "$RUNTIME_LOG" >/dev/null; then exit 1; fi

sleep 0.25
godot --headless --path "$ROOT" res://tests/lan_app_flow.tscn >"$APP_LOG" 2>&1 || { cat "$APP_LOG"; exit 1; }
cat "$APP_LOG"
if rg -n 'SCRIPT ERROR|ERROR:' "$APP_LOG" >/dev/null; then exit 1; fi

if rg -n 'SCRIPT ERROR|ERROR:' "$LOG_FILE" >/dev/null; then
  tail -100 "$LOG_FILE"
  exit 1
fi
printf 'verify-lan-runtime: PASS\n'
