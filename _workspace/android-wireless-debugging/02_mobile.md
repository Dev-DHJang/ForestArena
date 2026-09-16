# Mobile handoff

## Local environment evidence

- `adb` 확인: Android Debug Bridge 1.0.41, Platform-Tools 37.0.1-15733141.
- 2026-09-12: `adb devices -l`에서 `emulator-5554`만 `device` 상태로 확인.
- 물리 Android 기기는 연결되어 있지 않아 무선 페어링·설치·생명주기 검증은 미확인이다.

## Operator procedure

`docs/forest_arena/ANDROID_WIRELESS_DEBUGGING.md` 및 `scripts/android-wireless-debug.sh`를 사용한다. `pair`는 ADB의 대화형 입력으로 일회성 코드를 받고, 코드·endpoint·ADB 키를 저장하지 않는다.
