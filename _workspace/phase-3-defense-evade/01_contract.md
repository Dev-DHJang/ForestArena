# 계약 — CombatRules v2와 행동 입력

- `CombatRules` v2가 가드 내구 100, 유지 소모 0.5/tick, 가드 피격 `damage × 4`, 회복 지연 30 tick·회복 1/tick, 붕괴 45 tick, 회피 12 tick·무적 6 tick·480 px/s·체공당 1회를 소유한다.
- `dash`는 기존 안정 InputMap ID를 유지한다. 지상 중립 press/hold=가드, 지상 좌우 press=회피, 회피 완료 뒤 같은 좌우 hold=대시, 공중 press=방향 또는 facing 회피다.
- `snapshot()`은 가드 내구·회복 지연·공중 회피 잔여를 읽기 전용으로 제공한다. HUD·시각 표현은 판정을 계산하지 않는다.
- 모든 현존 AttackData는 첫 슬라이스에서 가드 가능하다. 가드 불가 판정·잡기·차지·궁극기 데이터는 추가하지 않는다.
