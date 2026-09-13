# 계약

- ADR-020은 차지를 제거하고 강공격을 `PRESS` 즉시 발동한다. tuning enum 8은 deprecated tombstone이며 거부하고, 특수기 cooldown 9와 공중 추진력 10은 보존한다.
- `CombatTuningData/Modifier v3`, `PassiveData v2`, `CancelRuleData v2`, `JobData v5`, `LoadoutCatalog v3`, `RuntimeCombatProfile v5`만 허용한다.
- Character → root-to-leaf Job → Accessory 순서로 합성하며 소스 Resource는 변경하지 않는다.
- passive는 발동 행동/context와 소비 행동/context를 분리한다. 동일 attack activation의 다단 적중은 한 번만 발동한다.
- cancel은 적중한 비피니시·비필살기 원 행동의 고정 ground/air context와 recovery 양 끝 포함 창에서만 발동한다. 목표 공격뿐 아니라 `jump`, `dash`도 데이터 규칙을 통과한 뒤 실행한다.
- 구버전, 누락 passive, 중복 passive/cancel, 잘못된 부모·stage·cycle은 profile 없는 원자 실패다.
