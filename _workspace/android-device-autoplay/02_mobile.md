# Android 자동 플레이 구현 기록

- 기준 코드: origin/develop cf081dd334ef619450d612844f6206f560ea2cc0. 별도 작업 트리와 codex/android-device-autoplay 브랜치에서 기존 사용자 작업·승인 자산을 보존했다.
- 실행 도구는 선택한 물리 기기 최대 4대, 오프라인 병렬, 인접 기기 두 대씩 LAN 검사를 지원한다. 중복 물리 기기의 서로 다른 ADB 연결 주소도 실행 전에 거절한다.
- AndroidQaSession은 명시적 debug 실행에서만 실행 ID별 저장·명령·관측 파일을 만든다. LocalAICommandSource와 CombatIntent, 기존 LAN v2 입력 순번·60Hz 전투를 재사용한다.
- 실제 터치·키 입력과 내부 설정·자동 전투를 구분하고 화면마다 최신 좌표를 읽는다. 전투 입력 누름·해제, 상태 변화, 재대전 초기 상태를 함께 검사한다.
- LAN 테스트 API는 메모리 안의 임시 게스트만 제공한다. 실제 APK의 닉네임·LAN 인증 경로를 유지하며 제품 DB/API 인증 검증과 구분한다.
- LAN 단절은 앱 소켓에만 적용한다. 10초 복귀·65초 이탈, 서버 입력 해제를 검사한다. 실제 Wi-Fi·동시 터치·소리·진동은 수동 검사다.
- Godot 4.7.1은 exported 시작 화면의 command_line_params를 제거한다. 생성 Android 템플릿에 debug 전용 어댑터를 넣어 `--`, qa-run, qa-device의 세 인자만 검증해 Godot 실행 목록에 전달한다. release의 BuildConfig.DEBUG와 Godot OS.is_debug_build 검사를 모두 적용한다. APK의 어댑터 표시와 debuggable 여부를 설치 전에 확인한다.
- 성능 자료는 FPS·프레임 p95·메모리·발열 관측값이며 합격 기준은 지정하지 않는다. 읽지 못한 정보는 미확인으로 남긴다.
- 예상하지 않은 ADB 단절·이전 프로세스 상태·일반 저장 변경은 통과 처리하지 않는다. 실행별 이전 결과를 보존한다.
