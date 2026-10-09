#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build/demo
FOREST_ARENA_ANDROID_PRESET="Android Demo" FOREST_ARENA_APK_PATH="build/android/ForestArena-demo.apk" ./scripts/export-debug-android.sh
godot --headless --path . --export-pack "Demo Server" build/demo/server.pck
python3 tools/forest_arena/package_demo.py
