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
require_badging "uses-permission: name='android.permission.VIBRATE'" "combat haptic feedback permission"
require_badging "native-code: 'arm64-v8a' 'x86_64'" "arm64 device and x86_64 emulator ABIs"

if $aapt_path list "$apk_path" | grep -E '(^|/)(_workspace|docs|tests|\.agents)/' >/dev/null; then
	echo "APK contains development-only documentation, tests, or workspace evidence" >&2
	exit 1
fi

for data_file in resource_registry.json audio_events_v01.json character_display_layout_v01.json; do
	if ! "$aapt_path" list "$apk_path" | grep -Fx "assets/forest_arena/data/$data_file" >/dev/null; then
		echo "APK contract mismatch: missing runtime data $data_file" >&2
		exit 1
	fi
done

python3 - "$apk_path" <<'PYCODE'
import hashlib, json, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as apk:
    names = set(apk.namelist())
    registry = json.loads(apk.read("assets/forest_arena/data/resource_registry.json"))
    menu = [asset for asset in registry["assets"] if ".menu.v07." in asset["id"]]
    assert len(menu) == 27, "프리미엄 메뉴 자산27개 등록 누락"
    for asset in menu:
        path = "assets/" + asset["path"].removeprefix("res://")
        assert path in names or path + ".import" in names, "프리미엄 메뉴 파일 누락: " + asset["id"]
    manifest = json.loads(apk.read("assets/forest_arena/assets/ui/premium-menu-v07/manifest.json"))
    font = next(asset for asset in manifest["assets"] if asset["logical_id"].startswith("fa.font."))
    license_bytes = apk.read("assets/" + font["license_path"])
    assert hashlib.sha256(license_bytes).hexdigest() == font["license_sha256"], "Noto Sans KR 라이선스 누락·변경"
print("Premium menu runtime assets and font license: PASS")
PYCODE

echo "Android APK contract verification passed."
