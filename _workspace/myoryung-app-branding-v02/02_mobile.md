# 묘령 상반신 아이콘 v02 Android 기록

2026-10-20. 앱 아이콘과 시스템 시작 아이콘만 변경했다. `project.godot`의 아이콘 경로, Android Debug·Demo 두 내보내기 설정의 일반·적응형 아이콘 경로를 v02로 변경했다. 시작 장면 `startup_title.tscn`, Godot 시작 로고 숨김(`show_image=false`)과 지연 0을 유지했다.

## 검사 명령

```sh
godot --headless --path . --script _workspace/myoryung-app-branding-v02/pack_icons.gd
./scripts/export-debug-android.sh
python3 _workspace/myoryung-app-branding-v02/verify_branding.py
```

출력 APK의 실제 Android WebP 아이콘·적응형 두 층·시스템 시작 아이콘과 `project.binary`를 확인한다. 숨은 RGB만 다른 투명 경계는 알파와 불투명 픽셀, 알파를 곱한 실제 색 차이로 구분한다. 일반 아이콘 원본과 파일 해시도 확인한다. Godot 화면을 띄운 것만으로 APK 검사를 대체하지 않는다.

## 이전 실기기 상태 (2026-10-20)

`adb devices -l`과 `adb mdns services`를 새로 실행했으나 연결된 기기와 검색된 무선 서비스가 모두 없었다. 기기 설치·런처 확인·첫 실행·재실행은 **미검증**이다. 에뮬레이터나 이전 v01의 검사 결과를 실기기 통과로 기록하지 않았다. 개인 기기 식별자·IP·포트는 기록하지 않는다.

## 새 APK 검사 결과

- Android Debug 내보내기와 `verify-android-package.sh`: 통과.
- 새 APK SHA-256: `5050b0021cc72159852275ce8024c0f04603f1fd662d70ad41a7db82dd632763`.
- 패키지 일반 아이콘·배경은 원본과 RGBA 픽셀까지 동일하다.
- 적응형 전경·시스템 시작 아이콘은 알파와 불투명 픽셀이 동일하다. WebP 변환 과정에서 alpha 0–19인 경계 RGB가 달라졌으며, 알파를 곱한 평균 색 차이는 255단계 중 약 0.0103이다. 실제 알파가 달라진 것으로 기록하지 않았다.
- Android 시작 화면의 하단 브랜드 이미지는 완전 투명이다.
- 패키지 `project.binary`의 아이콘은 v02, 시작 장면은 `startup_title.tscn`, Godot 로고 표시 false, 최소 표시 시간 0이다.
- 전체 결과는 `branding-checks.json`, 빌드 출력은 `android-export.log`, 검사 출력은 `branding-verification.log`를 참고한다.
- 빌드 중 ADB daemon 연결 경고가 있었으나 APK 내보내기와 패키지 검사는 성공했다. 이 경고를 실기기 연결 성공으로 해석하지 않는다.

## 2026-10-21 실기기 수행 결과

사용자의 실기 검증 지시에 따라 Galaxy S23 Ultra·Android16에 새 APK를 `adb install -r`로 설치했다. 설치된 APK와 빌드 SHA-256이 동일하다. 실제 런처·첫 실행·새 프로세스 재실행·Godot 로고 숨김·게임 시작 터치·HOME 복귀의6개 검사를 수행했고 독립 QA도 통과했다. 복귀 전후 실제 로비 픽셀은 동일하다. `physical-20261021/device-test-results.json`, `physical-20261021/03_qa_r01.md`와 공유용 영상이 실제 증적이다. 이전 미연결 조회는 과거 기록으로 남기며 이번 수행 결과로 갱신한다. 새 설치·오디오·장시간 성능은 미검증이다.
