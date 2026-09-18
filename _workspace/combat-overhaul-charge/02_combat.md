# 전투 구현

- 지상 강공격 press는 `CHARGE` 상태로 들어가고 release는 공격을 시작한다.
- 최소 차지 tick 이후에는 런타임 복제 AttackData에만 피해·넉백·회복 보정을 적용한다.
- 기존 v2 AttackData는 저장소 전용 v3 마이그레이션 도구로 명시적으로 변환한다.
