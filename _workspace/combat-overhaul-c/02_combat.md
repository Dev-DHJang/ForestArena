# 전투 구현 기록 — 묶음 C

- `CommandResolver`의 우선순위는 `아래+점프 발판 통과 > 아래+공격 > 아래 단독 가드`다.
- 발판은 전용 물리 계층 4와 one-way 충돌을 사용한다. 통과 중에는 그 계층만 12 tick 무시하고 일반 바닥 계층 1은 유지한다.
- 가드 해제, 회피, 특수기 쿨다운, 궁극기 게이지와 상태 사본은 `RuntimeCombatState`에 둔다.
- HUD는 `MatchController.snapshot()`의 HP·stock·가드·특수 쿨다운·궁극기 게이지만 읽는다.
- `CombatRules`는 게이지 획득률과 발판 통과 tick을 추가한 스키마 v3이며, `resave_combat_v3_resources.gd`가 저장소의 규칙 데이터를 명시적으로 재저장한다.
