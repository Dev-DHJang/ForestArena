#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() {
  echo "verify-online-server: FAIL: $*" >&2
  exit 1
}

for path in \
  server/api/package.json \
  server/api/package-lock.json \
  server/api/src/server.ts \
  server/game/game_server.gd \
  server/game/runtime_verifier.gd \
  server/game/token_verifier.gd \
  database/migrations/0002_local_online_vertical_slice.sql \
  scripts/server-dev.sh \
  tests/online_contract.gd \
  _workspace/local-online-vertical-slice/01_contract.md
do
  [ -f "$path" ] || fail "필수 파일 없음: $path"
done

grep -qF '127.0.0.1' database/.env.development.example || fail "기본 loopback 설정 없음"
grep -qF 'FOREST_ARENA_SERVER_BIND_HOST' database/compose.development.yml || fail "서버 bind 설정 없음"
grep -qF 'WebSocketMultiplayerPeer' server/game/game_server.gd || fail "Godot WebSocket 서버 없음"
grep -qF 'WebSocketMultiplayerPeer' scripts/network/online_dev_client.gd || fail "Godot 멀티플레이 WebSocket 클라이언트 없음"
grep -qF 'RECONNECT_GRACE_MSEC := 60_000' server/game/game_server.gd || fail "60초 재접속 계약 없음"
grep -qF 'SNAPSHOT_INTERVAL_TICKS := 3' server/game/game_server.gd || fail "20Hz snapshot 계약 없음"
grep -qF "status IN ('matched', 'running', 'ended')" database/migrations/0002_local_online_vertical_slice.sql || fail "경기 상태 제약 없음"

sh -n scripts/server-dev.sh
sh -n scripts/db-dev.sh
npm --prefix server/api test
godot --headless --path . --editor --quit
godot --headless --path . res://tests/online_contract.tscn

echo "verify-online-server: PASS"
echo "- 인증·매칭 단위 검사, WebSocket 계약과 Godot 권위 상태 검사 확인"
