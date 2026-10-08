# 미니맵 데이터 약속

- 프로필 v3: 기존 v2 항목 유지, nickname: String(기본 플레이어), minimap: {transparency: int 0..90 기본 30, marker_style: String face|dot 기본 face, show_names: bool 기본 true}. nickname은 앞뒤 공백 제거 뒤 1..12 Unicode 문자, 제어 문자 금지. 기기 v1/v2와 DB v2는 기존 값을 보존해 이전한다.
- 변경 명령: identity payload {nickname}, minimap payload 위 minimap 객체. 기존 accessibility 명령은 그대로 유지한다. 저장 성공 전 화면 사용 값을 변경하지 않는다.
- LAN protocol_version 1의 create_room/join_room에 선택적 nickname 추가. room_ready와 resumed joined에 names 사전 {"1": 이름, "2": 이름} 추가. 누락 시 참가자 1/참가자 2 사용. 방 입장 때 확정, 재접속·재대전 보존. 전투 snapshot과 입력 판정에 이름을 넣지 않는다.
- BattleMinimap API: configure(stage: StageData, participants: Dictionary, local_id: StringName, team_mode: bool), apply_settings(settings: Dictionary, text_scale: float = 1.0), update_snapshot(snapshot: Dictionary). participants는 fighter ID를 키로 {nickname, character_id, team_id}. snapshot position은 Vector2 또는 {x,y} 둘 다 처리한다. 탈락 stocks<=0 숨김.
- 얼굴은 승인 concept 이미지의 얼굴 영역을 AtlasTexture로 표시하고 논리 ID로만 로드한다. 카탈로그에 해당 ID가 없으면 기존 승인 파일을 가리키는 항목을 추가한다. 원본 PNG는 변경하지 않는다.
- 기존 진행 범위: ADR-028 제한 LAN 및 ADR-029 개발용 프로필에 표시 정보만 추가한다. 정식 계정·매칭·성장 기능은 추가하지 않는다.
