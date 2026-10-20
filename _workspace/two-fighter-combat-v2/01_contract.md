# 공용 데이터·역할 약속

## 전투 데이터

- AttackData v4는 기존 v3 필드를 유지하고, 데이터로 정의하는 타격 시점/복수영역/끌기/공격 이동/공중 행동 제한을 추가한다. 기존 v3는 명시적 호환 읽기로 기존 의미를 유지한다.
- runtime v4 선택 필드(확정): `hit_windows: Array[Dictionary]`, `pull_ticks: int`, `pull_stop_distance: float`, `air_lock: int`(0없음/1추가점프와공격/2모든입력), `landing_knockdown: bool`, `preserve_air_actions: bool`, `ground_only: bool`, `attack_movement: int`(0없음/1첫적뒤돌파), `travel_distance: float`, `travel_speed: float`, `behind_distance: float`, `hit_target_only: bool`.
- 각 hit_windows 항목은 `tick`(활성1부터시작), `boxes: Array[Rect2]`(오른쪽을 바라보는 fighter 원점 기준), 선택 `damage`, `knockback`, `launch_mode`, `launch_vector`, `hit_reaction`, `pull_ticks`, `pull_stop_distance`. 비어있으면 기존 active 사각형/재적중 규칙이다. 마지막 타격은 상대 적중 횟수가 아닌 기술 시점으로 결정한다.
- CombatRules v5는 기존 v4 호환 읽기와 `simplified_combat: bool=false`를 추가한다. 새 제품 경기에서는 true, special_cooldown_ticks300이며 기존 개발/기반 데이터는 false로 검증한다. 모든 새로운 행동 제한·지상방향통합은 rules/profile 기능값으로 분기하고 캐릭터 이름 분기는 없다.
- Fighter snapshot 추가 정수/불리언/좌표 필드명과 의미는 combat가 구현 뒤 이 문서에 확정 기록한다. 서버와 클라이언트가 같은 필드를 읽는다.
- 나비 이동은 기존 DASH 상태가 아닌 ATTACK_ACTIVE의 공격 소유 이동이다. 이동구간에만 pushbox 대상에서 제외하며 지형충돌/피격은 유지한다.

## 활성 제공·저장·네트워크

- 전체 원본 카탈로그/보유ID는 보존한다. LocalPlayCatalog의 `playable_characters()`는 활성2명의 CharacterData, `is_playable_character(id)`는 해당 여부를 반환한다. 캐릭터 선택/상점/AI/프리셋실행/LAN은 같은 필터를 쓴다.
- `normalize_combat_selection`은 기존 보유를 지우지 않고 비활성 선택을 보유한 활성 캐릭터(없으면 자현을 무료추가)로 바꾸며 선택 장신구는 미장착으로 바꾼다. DB 저장은 기존 저장 성공 후 반영 규칙을 따른다.
- LAN protocol3으로 올리고 이전2와 섞이지 않게 거부한다. 허용행동은 move/jump/attack_light/attack_heavy/attack_special이다. 서버도 활성2명/장신구없음만 허용한다.

## 소유권

- combat: AttackData/CombatRules/RuntimeCombatState/Fighter/HitResolver/HitContext/MatchController/Pushbox/두MoveSet 및 전투검사.
- UI·제품연결: LocalPlayCatalog/LocalPlayerStore/앱/터치/HUD/AI/네트워크서버·클라이언트/프로필·API 선택 제한 및 관련검사. combat 공용 파일을 수정하지 않고 부모에 변경 요청.
- motion-tools: 후보 catalog/scope/timeline/행위 검토 도구·검사와 승인 전 시안 자료. runtime PNG/manifest 수정 금지.
- orchestrator: 일반문서/실행검사명령/통합/독립QA/이미지시안생성 및 최종기록. 완성/미확인/승인대기를 구분한다.


## 전투 구현 확정 사항

- 기존 두 캐릭터 MoveSet은 보존한다. 새 파일은 `assets/combat/movesets/two_fighter_ja_hyun_moveset.tres`, `two_fighter_nabi_moveset.tres`이고 MoveSetData 형식은 v2, 포함한 공격은 AttackData v4다. 제품 카탈로그의 복사본만 이 두 파일로 연결한다.
- 새 규칙은 `assets/combat/two_fighter_combat_rules.tres`의 v5/`simplified_combat=true`다. 기반 검사와 기존 Resource는 기존 v4/false를 유지한다.
- LaunchMode는 기존 VECTOR=0/TOWARD_SOURCE=1을 보존하고 AWAY_FROM_SOURCE=2를 추가한다. 동일 좌표의 방향은 시전 시 고정한 바라보는 쪽으로 정한다.
- 자현 특수의 타격 시점은 활성 1부터 세어 **6,12,18,24,30,36,42,48,54,60**이다. 좌·우·위 영역이 겹쳐도 각 상대에게 한 펄스당 한 번만 맞고, 마지막 시점에 세 방향 모두 바깥으로 밀린다. 피해는 9×1+5=14다.
- 새 v4 SLAM/착지 다운 공격은 `knockback`을 피격자 아래 방향 최소 속도로도 사용한다. 자현 공중 강의 초기 아래 속도는 900 이상이며 규칙의 낙하 상한 1,000을 넘지 않는다. 시전자에는 이 속도를 적용하지 않는다.
- 나비 특수의 속도는 1,200px/s(60Hz에서 매 tick20px), 회복은20tick, 활성 최대 예약은24tick이다. 적을 만나 도착하면 마지막4개 활성tick으로 바로 옮겨 단타를 판정하고 회복20tick을 진행한다. 빈 대시나 막힘에는 타격 없이 즉시 회복20tick을 시작한다. 가까운 적에게 도착한 뒤 쓰지 않은 이동 시간을 기다리지 않는다.
- 나비는 이동 시작 때 중심 위치가 최대 320 안인 적 중 경로에서 가장 먼저 교차할 적을 고르고 ID로 동률을 정한다. 고른 적의 시작 위치에서 진행 방향으로 64 지난 점을 종점으로 고정한다. 종점 점유 또는 전체 이동 경로의 지형 충돌을 먼저 발견하면 시작 지점에서 실패한다. 이를 통해 적과 겹친 채 밀기 계산을 복원하여 벽 안으로 들어가는 문제를 막는다. 적이 없으면 320 이동하고 타격하지 않는다.
- 전체 공중 잠금·다운 중에도 이동 입력의 누름/해제 기록은 갱신하되 실제 입력에 따른 움직임은 막는다. 손을 뗀 기록이 사라져 잠금 해제 뒤 이동이 남지 않게 한다.
- 시간 제한은 첫 적용의 120tick이며 같은 체공 중 새 피격으로 연장하거나 만료 후 다시 시작하지 않는다. 만료는 추가 잠금/미발동 착지 효과만 해제하고 일반 피격 경직은 보존한다. 미사용 공중 기회만 이용할 수 있다.
- 신규 시각 상태 `attack_light_combo_04`/`special_scarf_sweep`는 승인 전 PNG·manifest를 등록하지 않는다. 기존 그림 재사용 또는 개발용 누락 표시는 새 안무 완료를 뜻하지 않는다.

## 전투 상태 기록 추가 필드

| 필드 | 형식·뜻 |
| --- | --- |
| `air_light_used`, `air_heavy_used` | bool, 체공 중 해당 공중 공격을 이미 사용했는지 |
| `air_lock` | int, 0 없음/1 추가 점프와 공격 제한/2 모든 행동 제한 |
| `air_lock_ticks`, `air_lock_expired` | int/bool, 최초 제한의 남은 tick과 이번 체공 중 만료 여부 |
| `landing_knockdown_pending` | bool, 다음 실제 착지 때 다운을 적용할지 |
| `landing_down_ticks`, `wakeup_protection_ticks` | int, 착지 다운/기상 보호의 남은 시간 |
| `pull_ticks_remaining`, `pull_speed`, `pull_stop_distance`, `pull_anchor` | int/float/float/{x,y}, 충돌을 유지하는 고정 목적지 끌기 상태 |
| `attack_travel_active`, `attack_target_id`, `attack_travel_end` | bool/string/{x,y}, 공격 이동 중인지·선택한 상대·고정 종점 |
| `attack_strike_ready`, `attack_travel_failed`, `attack_movement_started` | bool, 종점 타격 가능/실패/이동 초기화 완료 상태 |
| `on_floor` | bool, 실제 바닥 또는 발판에 닿았는지 |

경기 전체 상태에는 `simplified_combat: bool`을 추가한다. 좌표는 새 필드에서 `{x,y}`로 저장하므로 네트워크 직렬화에 Godot 전용 객체가 섞이지 않는다. `apply_network_snapshot`은 새 필드를 읽고 누락된 필드를 false/0/빈 ID/원점으로 읽는다. 기존 필드의 의미는 유지한다.
