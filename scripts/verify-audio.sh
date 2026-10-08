#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log_file=$(mktemp /tmp/forest-arena-audio-XXXXXX)
trap 'rm -f "$log_file"' EXIT INT TERM
python3 "$ROOT/tools/forest_arena/verify_audio_v01.py"
for test_script in phase6_audio_contract.gd audio_app_flow.gd; do
  if ! godot --headless --path "$ROOT" --script "res://tests/$test_script" >"$log_file" 2>&1; then
    cat "$log_file"
    exit 1
  fi
  cat "$log_file"
  if rg -q 'SCRIPT ERROR|ERROR:|Parse Error|: FAIL' "$log_file"; then
    echo "Audio verification failed: engine diagnostic in $test_script" >&2
    exit 1
  fi
done
echo "verify-audio: PASS"
