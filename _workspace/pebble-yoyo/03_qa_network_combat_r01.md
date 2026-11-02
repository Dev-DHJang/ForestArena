# 네트워크 담당의 독립 전투 읽기 검토 r01

검토 범위: 00_request·01_contract, FighterController·MatchController·HitResolver·CommandResolver·LocalAICommandSource와 pebble_yoyo_combat 검사. 실제 게임/모션 시각 검토는 포함하지 않는다.

## 확인

- 능력 데이터와 런타임 깊은 복사, 새 상태 enum 뒤 추가와 기존 상태 숫자 보존.
- 정확한30틱 경직은 기존 무게·배율을 거치지 않는다. HP·속도·공중 기회를 직접 변경하지 않고 더 긴 기존 경직은 유지한다.
- 가드 내구도 소모 없음, 무적·기상·다운·태그/경직 면역을 보존한다.
- 발사 중 segment-vs-expanded-hurtbox로 중간 위치를 검사하고 적중 집합으로 반복 적중을 막는다. 팀원·자가 타격을 제외한다.
- 일반 공격 적중을 먼저 처리하므로 같은 tick에 일반 공격에 맞은 시전자는 요요 판정이 제거된다. 장비 상호타격은 후보를 고정한 뒤 처리해 서로 맞을 수 있다.
- 장비 입력은 PRESS만 허용하며 명시된 같은-tick 우선순위를 따른다. 방향은 equipment_facing에 고정하고 쿨타임은 stock 변경으로 초기화하지 않는다.

## 추가 확인 요청

- StageController는 통과형 발판을 포함해 모든 지형을 collision_layer1에 둔다. _equipment_terrain_fraction의 mask1 주석만으로 발판 밑면을 제외할 수 없으므로 실제 통과형 발판 밑면 회귀를 전투 담당에게 요청했다.
- 같은 tick 일반공격에 의한 요요 중단, 사용 중 가드/방향 잠금 회귀를 전투 담당에게 요청했다.
- 최종 자동검사·실제 물리 충돌 검증·모션 시각 검토는 별도 결과를 따른다. 이 읽기 검토를 실행 통과로 기록하지 않는다.

## 전투 담당의 후속 수정

전투 담당은 실제 CollisionShape2D.one_way_collision을 읽어 발판 밑면·옆면 통과를 처리하고, 발판 통과·단단한 벽 귀환/벽뒤 피격 방지·같은tick 일반공격 중단·방향고정/가드거부 회귀를 추가했다고 보고했다. 중앙 실행 결과는 별도 검사 로그를 따른다.

## 실제 권위 서버 후속 검사

2026-10-30 `./scripts/verify-lan-runtime.sh` 최종 r03 통과. 실제 WebSocket 양쪽에서 고정물리틱 이동거리, 장비 장착 전달, 발사 적중의 무피해 경직,600틱 쿨타임 시작/재입력 거부, 비PRESS 입력 거부와 재접속 상태 복원을 확인했다. 고정틱 전투를 가변 `_process`에서 실행하던 기존 서버 버그를 `_physics_process`로 옮겨 해결했다. 로그: `build/verification/pebble-yoyo/lan-runtime-focused-r03.log`. 기기·모션 시각·운영 DB 검사는 이 결과에 포함하지 않는다.
