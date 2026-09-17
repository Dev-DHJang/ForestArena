# 전투 구현 기록 — 묶음 D

- `ComboLinkData`는 약→약과 적중 시 약→강/특수 분기를, `CancelRuleData`는 점프·가드·회피·특수·궁극기 취소 창을 정의한다.
- 리소스 재저장 도구는 네 MoveSet의 비피니시 지상 약공격에 해당 링크와 취소 규칙을 명시한다.
- 피격 반응은 데이터의 NORMAL_HIT·LIGHT_STAGGER·HEAVY_STAGGER·KNOCKBACK·KNOCK_DOWN·LAUNCH·GROUND_BOUNCE·WALL_BOUNCE·SLAM·CRUMPLE을 HITSTUN·KNOCK_DOWN·LAUNCH 상태로 해석한다.
- 장신구의 기술 슬롯 교체는 ComboLinkData뿐 아니라 CancelRuleData의 출발 기술 ID도 함께 갱신한다.
