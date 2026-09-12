# Phase 3 전투 계약

## 버전과 호환성

- `AttackData`, `CombatRules`, `JobData`, `RuntimeCombatProfile`의 현재 계약 버전은 2다.
- 저장·네트워크 호환 소비자는 아직 없으므로 저장소의 v1 리소스는 v2로 일괄 마이그레이션하고 v1 정의는 명시적으로 거부한다.
- CharacterData → 부모부터 누적한 JobData → AccessoryData 조합 순서와 소스 Resource 비변경성은 유지한다.

## 의미 입력

- 기존 `dash` ID는 행동 버튼 ID로 보존한다. 중립 유지 6 tick은 가드, 좌우 누름은 회피, 좌우 유지는 회피 뒤 대시다.
- `grab_support`는 가드 해제 뒤 12 tick 유예에서만 유효하고, `ultimate`는 별도 버튼이다.
- 지상 `attack_heavy`는 press 뒤 release 전까지 예약한다. 8 tick 미만 release는 일반 강공격, 8~60 tick은 차지 강공격이다.
- 모든 입력은 `CombatIntent`의 tick, fighter ID, action ID, direction, edge, context를 사용한다.

## 권위 상태와 충돌

- 파이터 snapshot은 가드, 회피, 잡기 유예, 차지, 특수 쿨다운, 궁극기 게이지·stock 사용 여부를 포함한다.
- 처리 우선순위는 회피 무적, 활성 일반 공격의 잡기 중단, 잡기의 가드 관통, 일반 공격의 가드 처리, 일반 적중 순이다.
- UI, 애니메이션, VFX와 telemetry는 전투 결과를 만들거나 수정하지 않는다.

## 데이터

- `AttackData`는 공격 종류, 가드 가능 여부·가드 피해, 차지 가능 여부, 쿨다운 그룹·tick, 궁극기 여부를 소유한다.
- `CombatRules`는 Phase 3 공통 기본값을 소유한다.
- `CombatTuningData`는 캐릭터 기본 전투 자원 값을, `CombatTuningModifier`는 직업의 필드별 add/multiply/set 변경을 소유한다.
- RuntimeCombatProfile은 조합된 tuning 복제본을 소유하며 공용 전투 코드에는 캐릭터·직업 이름별 분기를 두지 않는다.

## 명령 소스와 기록

- 로컬 입력과 `DeterministicBotCommandSource`는 같은 tick 기반 intent 배열을 MatchController에 제공한다.
- 봇 출력은 profile ID, seed, snapshot과 tick이 같으면 동일하다.
- telemetry는 `user://phase3-playtests/matches.jsonl`에 익명 매치·행동 집계만 기록하며 네트워크 전송과 성장 저장을 하지 않는다.

