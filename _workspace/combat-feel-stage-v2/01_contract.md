# 공용 계약

- `StageData` v1이 표면, 시작 위치, 링아웃 영역과 배경 ID의 단일 원본이다.
- `StageSurfaceData` v1은 표면 ID, world `Rect2`, 통과 여부를 가진다.
- `ComboLinkData` v2의 입력 구간은 회복 시작을 0으로 하는 상대 tick이다. 음수는 활성 종료 전 입력이다.
- `CombatRules` v4는 경기장 좌표를 소유하지 않고 전투 전역 값만 소유한다.
- 런타임 시각은 Body 충돌 모양의 아래 끝과 모션 `foot_pivot_y`를 맞추며 판정에 값을 되돌려 쓰지 않는다.
