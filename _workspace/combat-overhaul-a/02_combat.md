# 전투 구현 기록

- 결정론: 고정 tick의 입력·상태·적중 결과만 경기 권위다. 애니메이션과 시각 노드는 이를 바꾸지 않는다.
- 분리 목표: `FighterController`는 노드 조율, `AttackController`는 공격 단계, `ComboController`는 예약·연계, `CombatMath`는 수식, `HitResolver`는 적중 결과를 담당한다.
- 데이터의 `combo_step`과 피해율 기반 넉백 증가는 마이그레이션 뒤 권위에서 제거한다.
