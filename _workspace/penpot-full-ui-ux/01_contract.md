# 전투 UI 계약

- 단일 원본: `docs/ui/combat-ui-v01.json`.
- 소비자: Penpot `06_Combat` 페이지, `tests/combat_ui_design_contract.gd`, 향후 Godot HUD 구현.
- 표현 경계: HUD는 `damage_percent`, `stocks`, `winner_id`, `sudden_death_round`, `fighter_state`를 읽어 표시만 한다.
- 호환: 현재 `dash`, `jump`, `attack_light`, `attack_heavy`, `attack_special` 입력 순서와 6.5% safe edge를 유지한다.
- 제안 프레임: `CBT_PROP_*`는 런타임 변경 권한이 없으며 ADR-006은 proposed 상태로 유지한다.
