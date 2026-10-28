#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# Direct invocations and the shared runner use the same worktree lock.
SCRIPT_PATH="$ROOT/scripts/export-debug-android.sh"
if [ "${FOREST_ARENA_LOCKED_SCRIPT:-}" != "$SCRIPT_PATH" ]; then
  exec python3 "$ROOT/tools/forest_arena/workflow.py" --root "$ROOT" run -- \
    env FOREST_ARENA_LOCKED_SCRIPT="$SCRIPT_PATH" sh "$SCRIPT_PATH" "$@"
fi
cd "$ROOT"

apk_path=${FOREST_ARENA_APK_PATH:-build/android/ForestArena-debug.apk}
preset=${FOREST_ARENA_ANDROID_PRESET:-Android Debug}
debug_aar=$(find android/build/libs/debug -maxdepth 1 -name '*.aar' -print -quit 2>/dev/null || true)

if [ -f android/build/build.gradle ] && [ -n "$debug_aar" ]; then
	python3 tools/forest_arena/prepare_android_qa.py
	godot --headless --path . --export-debug "$preset" "$apk_path"
else
	template_backup=$(mktemp -d /tmp/forest-arena-android-template.XXXXXX)
	if [ -d android/build ]; then
		mv android/build "$template_backup/build"
	fi
	if ! godot --headless --path . --install-android-build-template --export-debug "$preset" "$apk_path" || ! python3 tools/forest_arena/prepare_android_qa.py || ! godot --headless --path . --export-debug "$preset" "$apk_path"; then
		if [ -d android/build ]; then
			mv android/build "$template_backup/failed-build"
		fi
		if [ -d "$template_backup/build" ]; then
			mv "$template_backup/build" android/build
		fi
		echo "Android template regeneration failed; previous template restored from $template_backup" >&2
		exit 1
	fi
	find "$template_backup" -depth -delete
fi
./scripts/verify-android-package.sh "$apk_path"
python3 tools/forest_arena/verify_branding.py --apk "$apk_path" --output "$apk_path.metadata.json"

echo "Android debug export passed: $apk_path"
