# Android 통합 기록

- Android debug APK 내보내기와 APK 계약 검사를 통과했다.
- Android 빌드 템플릿의 AAR이 없을 때 템플릿을 안전하게 다시 만드는 복구 경로를 내보내기 스크립트에 추가했다.
- `AnimalFight_API_35` 에뮬레이터에서 설치, 새 실행, 로컬 AI 대전 진입, 터치, 일시정지·재개, 경기 종료를 검사했다.
- APK: `build/android/ForestArena-debug.apk`
- 실제 Android 기기에서는 이번 변경을 실행하지 못했으므로 터치 감각, 성능, 중단·복귀는 **미확인**이다.
