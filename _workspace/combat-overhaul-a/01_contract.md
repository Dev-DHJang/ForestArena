# 전투 개선 공용 계약

## 버전과 실패

- `CharacterStats`, `AttackData`, `MoveSetData`, `AccessoryData`, `JobData`, `CombatRules`는 새 스키마 버전만 읽는다.
- 이전 버전은 보정하거나 조용히 추정하지 않고 `is_valid_definition()` 실패로 거부한다.
- 저장소의 승인 Resource는 새 버전으로 함께 옮긴다.

## 경기 상태

- 원본 Resource는 불변이다. `RuntimeCombatProfile`은 최종 능력치·기술·규칙·효과의 복사본이며, `RuntimeCombatState`가 경기 중 HP, stock, 상태, 자원과 타이머를 가진다.
- HP 0과 링아웃은 같은 stock 소모 흐름이다. 남은 stock이 있으면 45 tick 뒤 최대 HP로 복귀하고 60 tick 무적을 얻는다.
- 마지막 stock을 같은 tick에 잃으면 `DRAW`다. 부활 효과는 마지막 stock에서 한 번만 1 stock과 효과가 정한 HP를 설정하고 같은 복귀 흐름을 사용한다.

## 적중

- 결과는 `HIT`, `BLOCK`, `PERFECT_GUARD`, `ARMOR`, `IMMUNE`, `MISS`뿐이다.
- 순서: 공격자 보정 → 방어자 보정 → 가드 → 무적 → 아머 → 피해 → 반응 → 사후 효과. 궁극기의 명시적 무시 플래그만 아머·면역보다 먼저 적용한다.
- 넉백과 경직은 공격 데이터·무게·전역 상하한만 사용한다. HP나 누적 피해율을 사용하지 않는다.

## 조합

- 조합 순서는 `Character → 부모 직업 → 현재 직업 → 장신구`다.
- 공용 코드는 캐릭터·직업·장신구 ID를 직접 비교하지 않는다. 데이터는 능력치 수정, MoveSet/슬롯/연계, 명시 규칙, 효과를 제공한다.
