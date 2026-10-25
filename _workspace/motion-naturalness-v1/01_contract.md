# 모션 표시 데이터 약속

공용 담당: root. 아래 필드는 기존 manifest/candidate entry에 선택적으로 추가하며 전투·LAN 계약은 변경하지 않는다.

- `frame_count`: 생략16, 허용16/24/32. `atlas_columns`: 생략16,1..16이며 count이하. `cell_size`: 생략128,현재128만 허용. 시트 크기 columns×128, ceil(count/columns)×128. 행 우선 순서. 마지막 남는 셀은 비어 있다.
- `frame_durations`: 생략시 모두1.0. 제공하면 count개 양수 finite 실수. SpriteFrames의 각 frame duration과 같아야 한다. FPS는 기존 `fps`를 쓴다. durations는 표시 시간 가중치이며 전투 시간 아님.
- `phase_frame_ranges`: 기존3개 [begin,end) 구간. 준비/판정/회복이 겹치지 않고 전체count를 순서대로 덮는다. 해당 구간의 frame_durations 가중치를 실제 단계 시간에 맞춘다. 그림 수가 짧은 판정tick보다 많으면 후보 검토에서 거부한다(기존승인16재사용은경고/기존호환).
- `jump_frame_ranges`: 선택 dictionary: ascent/apex/descent/landing의 [begin,end), 순서대로전체count를덮는다. 공중에는landing 그림사용금지. 신규24의 기본값 [0,6],[6,10],[10,16],[16,24]. 기존필드descent_frame_range/landing_frame_range는그대로호환.
- `run_stride_px`: 선택양수, 한좌우발주기의월드이동거리. 신규대표세트96. 실제fighter위치변화로run위상진행, 순간이동/재등장/새run진입은리셋. idle상태에서는run위상을진행하지않는다. 기존자산은기존FPS재생유지.
- `frame_anchors`: 선택 count개 Dictionary. `scarf_root`/`scarf_hand`는128셀의Vector2를표현하는[x,y]. `scarf_tips`는두[x,y]의배열. 새효과는현재표시frame의anchor를읽고 sprite transform으로월드방향을맞춘다. 기존16후보의고정좌표는해당기존모션에만fallback. 새24/32에고정15clamp적용금지. anchor는표시만하며공격계산금지.
- 모든새메타데이터/레이아웃은기존asset_sha256에묶인다. 새PNG이름은_<count>f 버전형, 논리ID와기존tres소비경로는승인등록때유지. motion ID는visual_state_id우선,파일명은기존fallback.

담당분리: tools 에이전트=Python검토도구/candidate loader/timeline와해당테스트. runtime 에이전트=LocalPresentation/AttackEffects와Godot표시검사. root=제작·원화·후보포장·문서·최종통합. 기존승인120자산동작은기본값으로보존한다.

## 실제 연계 검토 뒤 접지 기준 보강

2026-10-22. `frame_anchors`의 각 그림에 선택 `body_root: [x,y]`를 추가한다. 원화 안에서 몸 전체의 표시 기준으로 삼을 128셀 좌표이며 두 좌표는 0..128의 유한 수다. 현재 표시 프레임의 이 점을 캐릭터의 실제 발 기준 위치에 놓는다. 반전 때 X 오프셋도 반전하고 목도리 효과는 보정된 sprite 변환을 따른다. 입력·이동·충돌·피해를 계산하지 않는다. 없거나 잘못되면 기존 공통 발 기준과 X=0을 유지한다.

이 항목은 손·얼굴 모양이나 비율을 바꾸지 않는다. 동일한 두 신발의 접지 중심이 시트의 각 행마다 흐르는 포장 위치 문제에만 사용한다. 픽셀을 잘라 옮기거나 특정 프레임만 축소하지 않는다. 실제 접지의 표시 위치를 맞춘 뒤 전체 연계·반전·소형 재생을 다시 검토한다.

## LAN 날림 종료의 짧은 표시 연결 시안

아래 선택 표시 값을 제품의 표시 코드가 읽는다. 현재 승인된 런타임 자산에는 값이 없으며, 새 모션 후보에서만 시험한다. LAN3·전투·저장 메시지는 바꾸지 않는다.

- `launch_release_frame_range`: launch 안에서 낙하로 잇는 그림 구간 `[begin,end)`이다. `0 <= begin < end <= frame_count`를 만족한다.
- `launch_release_ticks`: 이 연결을 보여 주는 표시 시간이다. 정수1~12이며 구간 그림 수 이상이어야 한다. 두 필드는 함께 있어야 하고 기본 시안은[12,16)·4틱이다.
- 실제 상태가 LAUNCH에서 JUMP/FALL로 바뀔 때만 검사한다. 마지막 launch 그림까지 이미 봤으면 연결을 반복하지 않는다. 아직 남은 후반 그림을 순서대로 짧게 보여 준 뒤 현재 점프/낙하로 이어진다.
- 새 공격·가드·회피·점프 입력의 결과 상태, 착지·피격·사망·리셋·프로필 변경은 연결을 즉시 끊는다. 공격·이동·경직·승패·전투 시간을 늘이거나 LAN의 없는 경직을 계산하지 않는다.
- 이미 값이 없는 승인 모션은 기존 표시를 유지한다. 새 값은 정확한 그림 해시에 묶고, 해당 모션의 새 연결 재생도 독립 검토·명시 승인에 포함한다.
- 정상/반전·가변 표시FPS·중복HIT·새 점프/공격·전투 상태와 내부 경직 불변·최초/마지막 그림·잘못된 쌍/범위의 거부를 검사한다.
