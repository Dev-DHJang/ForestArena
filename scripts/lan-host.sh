#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE_DIR="$ROOT/.godot/lan-host"
PID_FILE="$STATE_DIR/server.pid"
LOG_FILE="$STATE_DIR/server.log"
PORT=${FOREST_ARENA_LAN_PORT:-7777}

fail() {
  printf 'lan-host: %s\n' "$*" >&2
  exit 1
}

private_ip() {
  for interface in en0 en1; do
    value=$(ipconfig getifaddr "$interface" 2>/dev/null || true)
    case "$value" in
      10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) printf '%s\n' "$value"; return 0 ;;
    esac
  done
  return 1
}

running() {
  [ -f "$PID_FILE" ] && kill -0 "$(sed -n '1p' "$PID_FILE")" 2>/dev/null
}

case ${1:-} in
  start)
    running && fail "이미 실행 중입니다. $(sed -n '1p' "$PID_FILE")"
    address=$(private_ip) || fail "macOS의 사설 Wi-Fi IPv4 주소를 찾지 못했습니다."
    mkdir -p "$STATE_DIR"
    : >"$LOG_FILE"
    FOREST_ARENA_LAN_PORT="$PORT" \
    FOREST_ARENA_LAN_BIND_HOST="0.0.0.0" \
    FOREST_ARENA_LAN_ADVERTISED_WS_URL="ws://$address:$PORT" \
      nohup godot --headless --path "$ROOT" res://server/game/lan_game_server.tscn >"$LOG_FILE" 2>&1 &
    server_pid=$!
    printf '%s\n' "$server_pid" >"$PID_FILE"
    attempts=0
    while [ "$attempts" -lt 50 ]; do
      if grep -q 'FOREST_ARENA_LAN_READY' "$LOG_FILE"; then
        grep 'FOREST_ARENA_LAN_READY' "$LOG_FILE" | tail -1
        printf 'lan-host: 참가자의 Android 기기와 이 Mac을 같은 Wi-Fi에 연결하세요.\n'
        exit 0
      fi
      kill -0 "$server_pid" 2>/dev/null || { tail -30 "$LOG_FILE"; fail "서버가 시작 중 종료됐습니다."; }
      sleep 0.1
      attempts=$((attempts + 1))
    done
    fail "5초 안에 준비되지 않았습니다. 로그: $LOG_FILE"
    ;;
  stop)
    running || fail "실행 중인 LAN 서버가 없습니다."
    server_pid=$(sed -n '1p' "$PID_FILE")
    kill "$server_pid"
    rm -f "$PID_FILE"
    printf 'lan-host: 종료했습니다.\n'
    ;;
  status)
    if running; then
      printf 'lan-host: 실행 중 pid=%s\n' "$(sed -n '1p' "$PID_FILE")"
      grep 'FOREST_ARENA_LAN_READY' "$LOG_FILE" | tail -1 || true
    else
      printf 'lan-host: 중지됨\n'
      exit 1
    fi
    ;;
  logs)
    [ -f "$LOG_FILE" ] || fail "로그가 없습니다."
    tail -f "$LOG_FILE"
    ;;
  *)
    printf '사용법: ./scripts/lan-host.sh start|stop|status|logs\n' >&2
    exit 1
    ;;
esac
