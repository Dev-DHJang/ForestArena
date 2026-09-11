# Android 검증

- APK: `build/android/ForestArena-debug.apk`
- SHA-256: `9ec7d59ad30fcb392c04e9d44c3b5e3a7abbda2adc887b991f013f1e0ceff485`
- `./scripts/export-debug-android.sh`: PASS. package ID, 표시명, min API 29, target API 36, arm64-v8a/x86_64, 가로 화면, 개발 파일 제외 계약을 통과했다.
- `./scripts/verify-android-emulator.sh build/android/ForestArena-debug.apk`: PASS on `emulator-5554`; 설치, cold start, 가로 화면, 방향·ACTION·점프 터치 진단, Home 중단, hot resume, 입력 해제를 통과했다.
- Galaxy S23 Ultra: BLOCKED. 2026-09-12 실행 시 연결된 ADB 장치는 `emulator-5554`뿐이었다. 실제 기기를 연결한 뒤 같은 APK의 설치·ACTION hold/side evade·Home pause·hot resume·입력 해제를 재검증해야 한다.
