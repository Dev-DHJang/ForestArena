# 공용 변경 약속

- 현재 CombatRules v5에 선택 필드를 추가한다. hitstun_multiplier 기본1/현재2, landing_down_ticks 기본18/현재36, falling_ring_out 기본false/현재true, ring_out_hide_margin256, ring_out_confirm_ticks60. guard_break_ticks 현재60. 기존 기반 규칙은 그대로 읽는다.
- 현재 두 캐릭터 약 중간타 ComboLink는 회복 기준 -12..17 tick으로 동작 전체에서 하나의 PRESS를 예약한다. 회복 종료 후 시작하며 HOLD·피니시는 예약하지 않는다.
- 기존 상태 번호를 유지하고 FALLING_OUT을 끝에 추가한다. 아래 경계에서 해당 상태로 전이하여 조작·공격·피격·몸 충돌·AI 목표를 제외한다. 비표시선(아래 경계+256) 통과 때 숨기고60 tick 뒤 stock을 한 번 차감한다. 기존 RING_OUT은 부활 대기다. HP 사망은 기존 흐름이다.
- snapshot에 hitstun_ticks, landing_down_duration_ticks, ring_out_hidden(bool), ring_out_pending_ticks(int), debug_geometry(Dictionary)를 추가한다. debug_geometry는 hurtbox와 hitboxes의 사각형 목록이며 각 사각형은 {x,y,w,h}의 세계 좌표다. local은 실제 전투 getter를 읽고 LAN은 서버가 보낸 사각형을 읽는다. UI는 결과를 계산하지 않는다.
- LAN protocol4를 서버·클라이언트·검사에 함께 적용하고 이전 버전을 거부한다. 기기/DB 프로필 저장 형식은 바꾸지 않는다.
- 임시 디버깅 설정은 app.debug_hitboxes_enabled(bool), 기본false이며 메모리에서만 유지한다. match_scene.set_combat_debug_enabled(bool)로 현재 경기에 적용한다. 범례와 반투명 빨강 공격/파랑 피격 영역을 표시한다.
- 가드는 승인 hold frame을 사용한다. 입력 해제·방향 변경·중단·접속 해제 시 상태와 guarding을 함께 해제한다. 가드 붕괴 때 guarding=false이다.

역할: 주 담당은 전투·공용 snapshot·카메라·표시를 통합한다. UI 담당은 임시 설정·별도 overlay·UI 검사, LAN 담당은 protocol·공용 문서·검사 도구를 소유한다. 독립 QA는 구현 이후 전체 요구와 소비자를 검토한다. 실제 Android 검사는 사용자 승인 이연이다.
