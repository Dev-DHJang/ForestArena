#!/bin/sh
set -eu

apk_path=${1:-build/android/ForestArena-debug.apk}
android_sdk_path=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}

if [ -z "$android_sdk_path" ]; then
	android_sdk_path="$HOME/Library/Android/sdk"
fi

if [ ! -f "$apk_path" ]; then
	echo "APK not found: $apk_path" >&2
	exit 1
fi

aapt_path=$(find "$android_sdk_path/build-tools" -type f -name aapt | sort -V | tail -n 1)
if [ -z "$aapt_path" ]; then
	echo "Android aapt not found under: $android_sdk_path/build-tools" >&2
	exit 1
fi

badging=$($aapt_path dump badging "$apk_path")

require_badging() {
	pattern=$1
	description=$2
	if ! printf '%s\n' "$badging" | grep -F "$pattern" >/dev/null; then
		echo "APK contract mismatch: $description" >&2
		exit 1
	fi
}

require_badging "package: name='com.forestarena.welllbeing'" "package ID"
require_badging "sdkVersion:'29'" "minimum Android 10 / API 29"
require_badging "targetSdkVersion:'36'" "target API 36"
require_badging "application-label:'Forest Arena'" "application label"
require_badging "uses-feature: name='android.hardware.screen.landscape'" "landscape feature"
require_badging "uses-permission: name='android.permission.INTERNET'" "LAN WebSocket permission"
require_badging "native-code: 'arm64-v8a' 'x86_64'" "arm64 device and x86_64 emulator ABIs"

if $aapt_path list "$apk_path" | grep -E '(^|/)(_workspace|docs|tests|\.agents)/' >/dev/null; then
	echo "APK contains development-only documentation, tests, or workspace evidence" >&2
	exit 1
fi

echo "Android APK contract verification passed."
