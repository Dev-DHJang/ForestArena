# 공용 계약

## ID·저장

- 새 장신구 ID: `pebble-yoyo`; 캐릭터 자현·나비만 활성. 기존6장신구 ID·보유 기록 유지, 구매·실행 재활성화 없음.
- 기존 프로필 schema3 구조 유지. 활성장비 허용값은 빈 문자열 또는 소유한 pebble-yoyo. Godot·API·관리자 공용 profile_catalog 목록 갱신.
- AI별 장비는 기존 LocalMatchParticipant.selection.accessory_id를 사용. 앱 내 준비 상태만 유지.

## 능력 데이터·전투

- `AccessoryAbilityData` (`scripts/data/accessory_ability_data.gd`) 새 Resource. `AccessoryData.active_ability` 선택형이며 기존 schema2 호환. `RuntimeCombatProfile.active_ability`는 원본을 깊은 복사.
- 능력필드: ability_id, cooldown_ticks=600, startup_ticks=6, extend_ticks=18, return_ticks=18, recovery_ticks=6, reach=180, hitbox_size=(28,28), origin_offset=(24,-32). 생성 자산·장비별 이름 분기는 공용 전투에 금지.
- `use_equipment` PRESS. 입력 우선: 아래+점프 > 기존 일반공격 > 장비 > 아래가드 > 점프.
- 장비 준비·발사·회수·회복, 고정 방향, 개별 활성화 번호와 적중 집합을 권위 상태에서 관리. 좌우 속도0·중력 유지. 피격/탈락 시 제거. stock 변경으로 쿨타임 초기화 금지. 새 경기만 초기화.
- 순수 경직: 정확히30틱, 무게·배율 제외, 피해·추가 넉백·공중행동기회 변경 없음. 기존 더 긴 경직 축소 금지. 보호/가드 정책 유지. 실·귀환은 판정 없음, 적마다 한 번, 팀원 제외. 지형에 막히면 회수.

## 상태 전송·표현

공통 snapshot 필드(전투 담당이 생산, UI/LAN이 소비):
- equipment_cooldown_ticks:int>=0
- equipment_phase:string, 값 idle/startup/extend/return/recovery
- equipment_tick:int>=0 (전체 동작 시작부터 경과틱)
- equipment_phase_tick:int>=0 (현재 단계의 0기반 표시 틱; 벽에서 조기 회수해도 회수 단계의 첫 틱은0)
- equipment_facing:int (-1 또는1)
- equipment_position:{x:number,y:number} (권위 월드 위치)
- equipment_activation_serial:int>=0
- equipment_airborne:bool (현재 표현 지상/공중)

기존 Fighter snapshot의 runtime_profile.accessory_id로 장착 여부 확인. 누락 snapshot은 미장착·idle·0으로 해석. 시각은 판정 비권위.
모션 이름 `equipment_yoyo_ground`, `equipment_yoyo_air`; 후보는 _workspace/pebble-yoyo/motions/ 아래, 승인 전 runtime 파일 생성/manifest 등록 금지.
자산 논리 ID `fa.accessory.pebble.yoyo` (대표/상점), `fa.accessory.pebble.yoyo.combat` (전투).

## LAN

- protocol5, 서버·클라이언트·연결코드·운영검사 함께 갱신. LAN1~4 명시 거부.
- 서버는 허용 장비 ID와 실제 사용 조건·판정 권위. 기존 인증·프로필 보유 검증 경계는 유지; UI/저장/API가 미보유 장착을 거부한다.
- 클라이언트는 use_equipment 입력만 전달. 쿨타임·장비 궤적/피격 계산은 하지 않는다. 재접속은 최신 서버 snapshot 복원.

표현 메타데이터: `equipment_phase_frame_ranges`는4구간, `equipment_hand`는128px 셀 안의 실 연결점이다. 일반 공격의3구간 phase_frame_ranges와 분리하며 기존 형식을 변경하지 않는다.
