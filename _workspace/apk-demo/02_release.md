# APK·서버 배포 준비

- 데모 버전 0.1.0-demo / Android versionCode 2 / LAN 계약 2.
- 패키지 com.forestarena.welllbeing, 기존 Godot debug 서명 유지.
- 인증서 SHA-256: bcf26cb860d715b9c5516456724eabc12caa3603523a804984510cafd1e9d555.
- 서버는 지정한 사설 IP에 직접 API를 실행하고 별도 PostgreSQL 볼륨을 사용한다. DB는 loopback만 열며 비밀 파일은0600이다.
- 허용 네트워크를 검사하며 내부 API 서비스 인증을 사용한다. macOS PF 규칙 생성은 검사했으나 실제 적용은 sudo 암호가 필요해 미확인이다.
- 기존 데모 볼륨에서 인증 파일을 잃었을 때 새 비밀을 만들지 않는 검사 DEMO_EXISTING_VOLUME_CREDENTIAL_GUARD: PASS.
- 서버 stop/start와 실제 앱·API·DB·LAN 통합 DEMO_APP_RUNTIME: PASS.
- 전체 ./scripts/verify.sh, 문서, 리소스, Android APK 계약 및 apksigner 검사: PASS.
- 독립 ZIP manifest 확인과 ZIP만 추출한 전체 서버 시작·종료: PASS. 비밀 파일은 포함하지 않는다.
- 최종 ZIP SHA-256: c88b7a96b9a1f948f989883540374845751116092e0fd99b59ad1d0a94d0818f.

## 기기 확인

adb devices -l에 연결된 기기가 없다. Android 두 물리 기기의 직접 설치·업데이트 저장 보존·Wi-Fi 단절·복귀·터치·오디오·성능은 미확인이다. APK 생성과 headless 검사를 기기 통과로 기록하지 않는다.
