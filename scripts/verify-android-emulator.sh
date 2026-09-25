#!/bin/sh
set -eu

if grep -F 'run/main_scene="res://scenes/local_ai_app.tscn"' project.godot >/dev/null; then
	exec sh ./scripts/verify-android-local-ai.sh "$@"
fi

apk_path=${1:-build/android/ForestArena-debug.apk}
package_id=com.forestarena.welllbeing
android_sdk_path=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}

if [ -z "$android_sdk_path" ]; then
	android_sdk_path="$HOME/Library/Android/sdk"
fi

adb_path="$android_sdk_path/platform-tools/adb"
if [ ! -x "$adb_path" ]; then
	echo "Android adb not found: $adb_path" >&2
	exit 1
fi
if [ ! -f "$apk_path" ]; then
	echo "APK not found: $apk_path" >&2
	exit 1
fi

target_serial=${ANDROID_DEVICE_SERIAL:-}
if [ -z "$target_serial" ]; then
	target_serial=$($adb_path devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')
fi
if [ -z "$target_serial" ]; then
	echo "No Android emulator is connected. Set ANDROID_DEVICE_SERIAL to validate an explicitly selected Android device." >&2
	exit 1
fi

$adb_path -s "$target_serial" wait-for-device
$adb_path -s "$target_serial" install -r "$apk_path"
$adb_path -s "$target_serial" shell am force-stop "$package_id"
$adb_path -s "$target_serial" logcat -c

cold_start=$($adb_path -s "$target_serial" shell am start -W -n "$package_id/com.godot.game.GodotAppLauncher")
printf '%s\n' "$cold_start"
if ! printf '%s\n' "$cold_start" | grep -F "Status: ok" >/dev/null; then
	echo "Android emulator cold start failed" >&2
	exit 1
fi

boot_attempt=0
while ! $adb_path -s "$target_serial" logcat -d | grep -F 'OnGodotMainLoopStarted' >/dev/null
do
	boot_attempt=$((boot_attempt + 1))
	if [ "$boot_attempt" -ge 15 ]; then
		echo "Godot main loop did not start on the Android emulator" >&2
		exit 1
	fi
	sleep 1
done
sleep 3

physical_size=$($adb_path -s "$target_serial" shell wm size | awk -F': ' '/Physical size/ {print $2}' | tr -d '\r')
screen_width=$(printf '%s\n' "$physical_size" | awk -F'x' '{print $1}')
screen_height=$(printf '%s\n' "$physical_size" | awk -F'x' '{print $2}')
orientation=$($adb_path -s "$target_serial" shell dumpsys input | awk '/Viewport INTERNAL: displayId=0/ {for (i=1;i<=NF;i++) if ($i ~ /^orientation=/) {split($i,a,"="); print a[2]; exit}}' | tr -d ',\r')
if [ "$orientation" = "1" ] || [ "$orientation" = "3" ]; then
	landscape_width=$screen_height
	landscape_height=$screen_width
else
	landscape_width=$screen_width
	landscape_height=$screen_height
fi
dpad_right_x=$((landscape_width * 36 / 100))
dpad_y=$((landscape_height * 75 / 100))
jump_x=$((landscape_width * 63 / 100))
action_y=$((landscape_height * 82 / 100))
$adb_path -s "$target_serial" shell input tap "$dpad_right_x" "$dpad_y"
$adb_path -s "$target_serial" shell input tap "$jump_x" "$action_y"
touch_log=$($adb_path -s "$target_serial" logcat -d -s godot:I Godot:I '*:S')
if ! printf '%s\n' "$touch_log" | grep -F 'FOREST_ARENA_TOUCH action=move_right edge=press' >/dev/null; then
	echo "Android emulator D-pad touch diagnostic missing" >&2
	exit 1
fi
if ! printf '%s\n' "$touch_log" | grep -F 'FOREST_ARENA_TOUCH action=jump edge=press' >/dev/null; then
	echo "Android emulator jump touch diagnostic missing" >&2
	exit 1
fi

$adb_path -s "$target_serial" shell input keyevent KEYCODE_HOME
hot_resume=$($adb_path -s "$target_serial" shell am start -W -n "$package_id/com.godot.game.GodotAppLauncher")
printf '%s\n' "$hot_resume"
if ! printf '%s\n' "$hot_resume" | grep -F "Status: ok" >/dev/null; then
	echo "Android emulator hot resume failed" >&2
	exit 1
fi

resume_log=$($adb_path -s "$target_serial" logcat -d -s godot:I Godot:I '*:S')
if ! printf '%s\n' "$resume_log" | grep -F 'FOREST_ARENA_INPUT_RESET reason=pause' >/dev/null; then
	echo "Android emulator pause did not report an input reset" >&2
	exit 1
fi

activities=$($adb_path -s "$target_serial" shell dumpsys activity activities)
if ! printf '%s\n' "$activities" | grep -F "topResumedActivity=" | grep -F "$package_id/com.godot.game.GodotAppLauncher" >/dev/null; then
	echo "Forest Arena is not the top resumed activity" >&2
	exit 1
fi

input_state=$($adb_path -s "$target_serial" shell dumpsys input)
if ! printf '%s\n' "$input_state" | grep -E 'Viewport INTERNAL: displayId=0.*orientation=(1|3).*logicalFrame=.*isActive=\[1\]' >/dev/null; then
	echo "Forest Arena is not running in an active landscape viewport" >&2
	exit 1
fi

echo "Android target install, landscape, touch, input reset, cold start, background, and hot resume passed: $target_serial"
