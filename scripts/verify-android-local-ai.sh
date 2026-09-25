#!/bin/sh
set -eu
apk_path=${1:-build/android/ForestArena-debug.apk}
sdk_path=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}
adb_path="$sdk_path/platform-tools/adb"
target_serial=${ANDROID_DEVICE_SERIAL:-}
if [ -z "$target_serial" ]; then target_serial=$($adb_path devices | awk '$1 ~ /^emulator-/ && $2 == "device" {print $1; exit}'); fi
if [ -z "$target_serial" ]; then echo 'No test device connected.' >&2; exit 1; fi
package_id=com.forestarena.welllbeing
device() { "$adb_path" -s "$target_serial" "$@"; }
device install -r "$apk_path"
device shell am force-stop "$package_id"
device logcat -c
device shell am start -W -n "$package_id/com.godot.game.GodotAppLauncher"
screen_size=$(device shell wm size | awk -F': ' '/Physical size/ {print $2}' | tr -d '\r')
width=$(printf '%s' "$screen_size" | awk -Fx '{if ($1>$2) print $1; else print $2}')
height=$(printf '%s' "$screen_size" | awk -Fx '{if ($1<$2) print $1; else print $2}')
# Debug-only button geometry reflects the actual safe-area/UI layout. No profile
# injection, gameplay shortcut, or removal of existing user data is performed.
tap_button() {
  label=$1
  attempt=0
  while [ "$attempt" -lt 15 ]; do
    coordinates=$(device logcat -d -s godot:I '*:S' | python3 -c '
import sys,json
result=None
for line in sys.stdin:
 if "FOREST_ARENA_UI_BUTTON " not in line: continue
 try: item=json.loads(line.split("FOREST_ARENA_UI_BUTTON ",1)[1])
 except ValueError: continue
 if item["text"] == sys.argv[1]: result=item
if result: print(round(result["x"]*int(sys.argv[2])),round(result["y"]*int(sys.argv[3])))
' "$label" "$width" "$height")
    if [ -n "$coordinates" ]; then
      echo "UI touch: $label at $coordinates"
      device logcat -c
      # A zero-duration ADB tap can be coalesced on a slow software renderer.
      # Hold and release at the same position, like an actual finger press.
      device shell input swipe $coordinates $coordinates 600
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  echo "Button not found: $label" >&2
  return 1
}
sleep 3
if device logcat -d -s godot:I '*:S' | grep -F '"screen":"first"' >/dev/null; then tap_button '자현'; fi
tap_button '대전 준비'
tap_button '대전 시작'
sleep 2
device shell input tap $((width * 43 / 100)) $((height * 76 / 100))
device shell input tap $((width * 78 / 100)) $((height * 69 / 100))
sleep 1
touch_log=$(device logcat -d -s godot:I '*:S')
printf '%s' "$touch_log" | grep -F 'FOREST_ARENA_TOUCH action=move_right edge=press' >/dev/null
printf '%s' "$touch_log" | grep -F 'FOREST_ARENA_TOUCH action=jump edge=press' >/dev/null
device shell input keyevent KEYCODE_HOME
sleep 1
device logcat -c
device shell am start -W -n "$package_id/com.godot.game.GodotAppLauncher"
sleep 2
tap_button '계속하기'
tap_button '일시정지'
tap_button '대전 종료 · 준비 화면'
tap_button '로비'
echo 'Android local AI: launch, owned selection, match, touch, pause/resume and return PASS.'
