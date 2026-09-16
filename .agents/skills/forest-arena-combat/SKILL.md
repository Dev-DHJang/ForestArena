---
name: forest-arena-combat
description: 결정론적 Forest Arena 2D 이동·상태·공격·피격 판정·링아웃·로드아웃을 구현한다.
---

# Forest Arena 전투

## 사용 시점

- 이동, 점프, 대시, 상태, 공격 단계, 판정, 넉백, 링아웃과 로드아웃 동작에 사용한다.
- 카메라·애니메이션·오디오 표현만 바꾸는 작업에는 사용하지 않는다.

## 필수 입력

- 현재 Phase, docs/gameplay/combat.md, docs/engineering/architecture.md와 관련 ADR.
- 공격·상태 데이터, 계약, 수용 기준과 UI·시각 소비자.

## 작업 흐름

1. 동일 초기 상태·입력·tick의 동일 결과와 시각 비권위를 불변 조건으로 둔다.
2. 상태 전이와 startup/active/recovery를 AttackData와 상태 머신으로 제어한다.
3. 공용 코드에 캐릭터·직업·장신구 이름별 분기를 넣지 않는다.
4. 자가 타격, 단발 반복 적중과 소스 Resource 변경을 막는다.
5. 자동 테스트 또는 이름 있는 수동 회귀를 추가한다.

## 산출물과 검증

- _workspace/<topic>/02_combat.md, 구현·데이터·계약 소비와 테스트.
- 빗나감, 단일·동시 적중, 경계 상태, 넉백, 링아웃, 조합 순서와 프레임 변동을 검사한다.
