#!/bin/sh
# Pair, connect, and inspect a physical Android device through Wireless debugging.
# Requires Android 11+ and an ADB executable available via ANDROID_SDK_ROOT,
# ANDROID_HOME, or the default macOS SDK installation path.
set -eu

usage() {
	cat <<'EOF'
Usage:
  ./scripts/android-wireless-debug.sh devices
  ./scripts/android-wireless-debug.sh pair <host:pairing-port>
  ./scripts/android-wireless-debug.sh connect <host:debug-port>
  ./scripts/android-wireless-debug.sh verify <serial>

On the Android device, open Developer options > Wireless debugging:
  - Select "Pair device with pairing code" for the pair endpoint.
  - Use the endpoint shown on the Wireless debugging page for connect.

The pairing code is requested interactively by adb and is never stored.
EOF
}

android_sdk_path=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
if [ -z "$android_sdk_path" ]; then
	android_sdk_path="$HOME/Library/Android/sdk"
fi
adb_path="$android_sdk_path/platform-tools/adb"

if [ ! -x "$adb_path" ]; then
	echo "Android adb not found: $adb_path" >&2
	exit 1
fi

command_name=${1:-}
case "$command_name" in
	devices)
		"$adb_path" devices -l
		;;
	pair)
		endpoint=${2:-}
		if [ -z "$endpoint" ]; then
			usage >&2
			exit 2
		fi
		"$adb_path" pair "$endpoint"
		;;
	connect)
		endpoint=${2:-}
		if [ -z "$endpoint" ]; then
			usage >&2
			exit 2
		fi
		"$adb_path" connect "$endpoint"
		;;
	verify)
		serial=${2:-}
		if [ -z "$serial" ]; then
			usage >&2
			exit 2
		fi
		state=$("$adb_path" -s "$serial" get-state 2>/dev/null || true)
		if [ "$state" != "device" ]; then
			echo "Device is unavailable or unauthorized: $serial (state: ${state:-unknown})" >&2
			exit 1
		fi
		model=$("$adb_path" -s "$serial" shell getprop ro.product.model | tr -d '\r')
		android_version=$("$adb_path" -s "$serial" shell getprop ro.build.version.release | tr -d '\r')
		printf 'Connected Android device ready: %s (model: %s, Android: %s)\n' "$serial" "$model" "$android_version"
		;;
	-h|--help|help|'')
		usage
		;;
	*)
		usage >&2
		exit 2
		;;
esac
