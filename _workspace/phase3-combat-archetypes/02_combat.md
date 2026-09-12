# Phase 3 전투 인수인계

## 구현

- `FighterController`는 hold 가드, 회피 무적, 가드 해제 뒤 잡기 grace, 지상 강공 차지, 그룹 공유 특수기 쿨다운, 궁극기 capture/follow-up을 권위 상태로 처리한다.
- `MatchController`는 로컬 터치와 `DeterministicBotCommandSource`를 동일한 CombatIntent 소비 경로로 처리하며, 충돌 우선순위는 회피 무적 → 활성 일반 공격의 잡기 중단 → 잡기의 가드 관통 → 일반 가드 → 일반 적중이다.
- 모든 Phase 3 값은 `CombatTuningData` 및 직업 modifier에서 유도한다. 캐릭터 ID 조건문은 사용하지 않는다.
- telemetry는 `user://phase3-playtests/matches.jsonl`에 익명 매치·행동 집계만 기록한다. 가드·회피·잡기는 입력 시도와 권위 판정 성공을 각각 한 번씩 분리해 기록한다.

## 확인할 사항

- 궁극기는 capture가 가드·회피·startup 일반 공격에 대응되며, 비가드 capture 적중일 때만 후속 다단을 예약한다.
- stock 상실 때 궁극기 게이지와 사용 여부를 초기화한다.
- 전문 직업은 공중 사용 횟수 상한을 우회하지 않는다.
