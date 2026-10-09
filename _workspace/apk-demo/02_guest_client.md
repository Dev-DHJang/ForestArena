# 데모 게스트 클라이언트 구현·검사

- 구현: `scripts/network/demo_guest_client.gd`. 개발용 DbProfileClient나 기기 보유 저장은 변경하지 않는다.
- 공개 동작: `login(api_url,new_guest=false)`, `set_nickname(value)`는 비동기 bool, `cancel()`은 진행 작업을 취소한다. busy/error/session_invalid/access_token/player_id/nickname을 화면에서 읽는다.
- `user://demo_guest_session.json`에 API 주소·게스트 ID·갱신 토큰·진행 중 갱신 쌍만 저장한다. access token과 기기 보유는 저장하지 않는다. 임시 파일 flush 후 rename으로 원자적으로 교체한다.
- 최초 guest 생성 후 저장 성공 이전에는 access token을 공개하지 않는다. 갱신 전 predecessor/successor를 먼저 저장하고, 응답/최종 저장 실패 때 동일 쌍을 재사용한다.
- 주소 변경·손상 세션·만료 세션은 명시적인 새 게스트 선택을 요구한다. 자동으로 기존 게스트를 대체하지 않는다.
- 인증 요청마다 별도 HTTPRequest와 종료 신호를 사용한다. cancel은 요청을 중단하고 신호를 완료시켜 대기 함수를 종료한다. 세대 번호가 바뀐 응답은 UI 필드나 파일에 반영하지 않는다.
- 인증된 profile 요청의 401은 한 번만 refresh와 재시도한다. 닉네임 형식과 중복 판단은 API가 수행하며 실패 때 기존 표시 이름을 유지한다.

## 자동 검사

`godot --headless --path . --script res://tests/demo_guest_client.gd` → PASS.

검사: 최초 게스트·닉네임 미설정, 저장에 access token/보유 제외, 주소 변경 시 원본 파일 보존, 기존 게스트 갱신, 닉네임 충돌/성공, 불확실 갱신 재시도 쌍 유지, 만료 시 자동 생성 금지, 최초 저장 실패, 갱신 완료 저장 실패 후 원래 쌍 재시도, 손상 세션 거부, 취소된 늦은 응답의 표시 이름/디스크 변경 금지.

테스트 transport는 결정적인 응답 fixture를 사용한다. API·DB 실제 연결과 두 Android 물리 기기 흐름은 별도 통합 검사이며 이 기록은 기기 통과 증거가 아니다.

추가 검사: 임시 localhost HTTP 서버가 1초 뒤 guest 응답을 보내도록 실행하고, 실제 HTTPRequest를 50ms 후 취소했다. 코루틴 종료·busy 해제·cancelled 유지·늦은 응답 뒤 세션 미생성 모두 PASS. 임시 서버/스크립트는 종료·삭제했다. 이 검사는 PostgreSQL 통합이나 물리 기기 검사에 해당하지 않는다.

## 실제 앱·API·DB·LAN 통합 검사

`godot --headless --path . res://tests/demo_app_runtime.tscn -- --demo` → DEMO_APP_RUNTIME: PASS.

준비된 API `127.0.0.1:3001`과 LAN `127.0.0.1:7778`, 데모 PostgreSQL을 사용했다. 두 LocalAiApp 인스턴스마다 기기 파일과 데모 세션 파일을 분리했다. UI의 게스트 접속·닉네임 입력/저장·중복 이름 거부·계속 버튼·방 생성/참가·취소 버튼을 실행했다. 두 실제 앱의 경기 진입, 서버 확인 이름의 미니맵과 결과 표시, 참가자 이탈 결과, 개발 DB 메뉴 숨김과 오프라인 5개 모드 유지도 확인했다. 별도 새 DemoGuestClient 인스턴스가 동일 세션 파일로 같은 게스트 ID와 PostgreSQL 닉네임을 복원했다. 시험 기기 파일은 제거하며 서버 시험 게스트는 고유 이름으로 생성된다.

이 통합 검사는 headless 데스크톱이며 Android 두 물리 기기의 터치·Wi-Fi·설치·업데이트 검사는 아직 별도다.
