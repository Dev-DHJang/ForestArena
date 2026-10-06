#!/bin/sh
set -eu

apk_path=build/android/ForestArena-debug.apk
debug_aar=$(find android/build/libs/debug -maxdepth 1 -name '*.aar' -print -quit 2>/dev/null || true)

if [ -f android/build/build.gradle ] && [ -n "$debug_aar" ]; then
	godot --headless --path . --export-debug "Android Debug" "$apk_path"
else
	template_backup=$(mktemp -d /tmp/forest-arena-android-template.XXXXXX)
	if [ -d android/build ]; then
		mv android/build "$template_backup/build"
	fi
	if ! godot --headless --path . --install-android-build-template --export-debug "Android Debug" "$apk_path"; then
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

echo "Android debug export passed: $apk_path"
