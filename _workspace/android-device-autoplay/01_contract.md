# Android 자동 검사 데이터 약속 v1

- `--qa-run=<영문·숫자·밑줄·하이픈 1~64자>`, `--qa-device=<별칭>`과 debug 빌드에서만 시작한다. 일반·release 실행에서는 꺼진다.
- `user://qa/<run>/`에서 local_player, db_profile_session, demo_guest_session 저장을 분리한다.
- command.json: schema_version=1, run_id, seq 양의 정수, case_id, device 별칭, step, expected, observed, op, args. expected는 명령 응답 순번과 빈 오류이고 발행 시 observed는 pending(아직 관측하지 않음)이다. 새 순번만 실행하고 결과는 state.json의 command_seq/command_error로 확인한다. commands.jsonl에는 같은 순번의 요청과 실제 응답 또는 대기 실패를 기록한다. 추가 진단 필드는 기존 v1 Godot 명령 처리와 호환되며 전투 입력 의미를 바꾸지 않는다.
- 명령: context, observe, autoplay(enabled), choose(id,index), set_text(id,value), select_config(character,accessory,opponent,mode,solo_count,team_size), interrupt(seconds=10 또는65).
- state.json: version/run/device/case/step, 화면·현재 UI 위치·선택 목록·프로필·전투 상태·결과·입력/이벤트·성능. UI 위치는 viewport의 0~1 비율이다.
- LAN 결과는 기존 winner_slot/final_tick/snapshot_hash/reason을 그대로 관찰한다. token·키·서명 정보는 출력하지 않는다.
- 실제 터치와 내부 설정·자동 전투는 결과의 입력 방식으로 구분한다. 내부 명령으로 실제 터치 통과를 대신하지 않는다.
- 호스트 결과 상태: pass/fail/blocked/미실행. 결과 JSON에는 기대값·관측값·기기별 시도·코드/APK 식별·증거 경로를 둔다.
