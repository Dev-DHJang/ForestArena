# LAN4와 공용 문서 연결

담당 범위는 LAN 서버·클라이언트·연결 코드, LAN 검사 소비자, Android 검사 도구의 기본 통신 버전과 현재 기준 문서다.

- LAN protocol4와 FAH4/FA4 코드를 함께 적용했다. 연결 코드의1·2·3 및 서버/클라이언트의 다른 protocol 메시지는 명시적으로 거부한다.
- 실제 두 WebSocket 클라이언트 검사에 서버의1·2·3·99 거부, 양쪽 snapshot의 경직·다운·낙하·실제 사각형 필드 수신을 추가했다. 클라이언트 단위 검사는 LAN3 snapshot을 UI에 전달하기 전에 거부하는지 확인한다.
- Android fleet 기본값은4이며 과거1·2·3 소스/배포 검사 선택지는 명시적 비교용으로 보존했다. 도구의 현재 제품 정책은3과4 모두 자현·나비 미장착이다.
- 공용 JSON, 현재 전투 문서·README·색인·LAN/데모 사용법·Android 검사 안내를 갱신했다. 과거 ADR-035 문장은 보존하고 사용자 승인 변경을 ADR-036으로 추가했다.
- 실제 Android 검사는 요청대로 별도 진행한다. Godot/LAN 실행은 주 담당의 단일 검사 일정에 통합한다.

검증: `python3 -m py_compile tools/forest_arena/android_fleet.py tools/forest_arena/test_android_fleet.py`와 `git diff --check` 통과. Python mock 단위 검사 결과는 `build/verification/combat-input-ringout-lan/android-fleet-unit.log`에 기록했다. 실제 기기 실행은 포함하지 않는다.
