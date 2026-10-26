# 피격 모션 구현 전달

## 재현

`repro.gd`는 실제 `apply_hit`를 자현·나비에 호출한다. 이전 16프레임 경직 중 새 경직을 30·10·6프레임으로 각각 바꾼 6경우가 모두 첫 그림 재진입에 실패했다. 총80검사 중6실패(`qa/before-r01.log`).

## 표시 전용 설계

- `apply_hit`가 실제 피격 상태를 정한 뒤 값을 싣지 않은 `hit_reaction_started` 신호를 보낸다. 경직을 계산하거나 변경하지 않는다.
- 표시 코드는 이 신호마다 재생 시간을 초기화한다. HITSTUN은 이미 정해진 경직의 남은 tick을 읽어 첫 그림부터 끝 그림까지 그 시간 안에서 표시한다. 발사·넘어짐의 기존 착지 처리는 그대로 둔다.
- main의 기존 표현 이벤트를 각 표시 노드에 전달한다. 나중에 생성된 LAN 표시 노드도 전달 시 찾는다.
- LAN의 기존 `hit_resolved` 결과가 HIT이고 대상 ID가 일치할 때에만 다시 재생한다. 기존 `epoch`·`event_seq`와 앞서 처리한 이벤트의 `tick`으로 중복·지난 경기·이미 처리한 시점보다 오래된 타격을 제외한다. 이미 로컬 신호로 처리한 같은 이벤트도 두 번 재시작하지 않는다. 이벤트가 idle·사망 등 전투 상태를 피격으로 바꾸지는 않는다.
- LAN3에는 남은 경직 필드가 없으므로 LAN은 승인 모션의 기존 FPS로 재생하고 서버 상태 변경 즉시 다음 동작으로 전환한다. UI에서 누락된 경직을 추측 계산하지 않는다. 로컬과 LAN의 첫 프레임 재진입은 동일하게 확인한다.

제품 파일 고정 해제 뒤 `fighter_controller.gd`·`local_fighter_presentation.gd`·`main.gd`에 적용했다. `fighter_attack_effects.gd`는 수정하지 않았다.

## LAN 순서 확인

서버 `lan_game_server.gd`의 표현 이벤트와 snapshot은 동일한 `_broadcast`를 사용한다. 클라이언트 `lan_match_client.gd`는 하나의 WebSocket에서 받은 패킷을 순서대로 `_handle_message`에 전달한다. 현재 제품 경로에서는 HIT가 해당 tick의 snapshot보다 먼저 전송된다. 그럼에도 snapshot tick만으로 유효 HIT를 버리지 않도록 구현했다. snapshot 80을 먼저 적용한 뒤 아직 HITSTUN인 상태에서 새 event_seq의 HIT 70을 받는 검사도 첫 프레임으로 재진입한다. 이미 처리한 event_seq·이전 epoch·직전 이벤트보다 과거 tick은 거른다. 현재 상태가 idle·death·match end라면 어떤 HIT도 피격 상태를 만들지 않는다.

## 생산자 자동 확인

- `tests/hit_reaction_presentation.gd`: PASS 330검사(`qa/after-r05.log`). 같은 남은10tick, 연장30tick, 축소6tick, 최종 그림과 즉시 idle, 로컬 신호+이벤트 중복 방지, 실제 main 연결, LAN 재진입·중복·이전 경기·과거 tick·다른 대상·비HIT, 재시작·프로필 교체, launch/down 반복, 실제 HitResolver의 가드·무효·갑옷·가드 파괴를 검사했다.
- `tests/motion_lifecycle_presentation.gd`: PASS 430검사.
- `tests/variable_motion_presentation.gd`: PASS 53검사.
- `tests/two_fighter_presentation.gd`: PASS.
- 새 검사에서는 자동 효과음을 끈다. 시각 또는 경직 검사에 소리가 필요하지 않으며 오디오 재생을 남겨 종료하지 않는다.

이 기록은 생산자 검사다. 독립 QA와 최종 통합 verify, 실제 연결 검사는 조율 역할에 전달했다. Android 실제 기기 확인은 하지 않았다.
