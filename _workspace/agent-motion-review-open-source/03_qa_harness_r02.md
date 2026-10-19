# 역할 체계·모션 검토 도구 독립 QA 2회차

- 검토자: 독립 QA 하위 에이전트 `review_myo`
- 검토일: 2026-10-19
- 검토 대상: 보강된 도구·단위 테스트와 원본 프로젝트의 `timeline-r03.json`.
- 판정: **fix**. 1회차 핵심 재현 3건과 실제 동적 차지 수집은 개선됐다. 단계 순서와 전체 차지 변형 누락 검사는 아직 부족하다.

## 검토 기준과 실제 증거

Python 도구·exporter는 구현 작업 폴더에서 읽고, 실제 r03의 해시는 수집 대상인 `/Users/jdh/Desktop/workspace/ForestArena`와 대조했다. 두 checkout의 전투·표현·moveset가 서로 달라 구현 작업 폴더를 r03의 실행 기준으로 쓰면 안 된다.

- 기존 자동 검사: `python3 -m unittest discover -s tools/forest_arena -p test_motion_action_review.py -v` — 20개 모두 통과.
- 1회차 원문 변경 재현: `docs/gameplay/combat.md` 변경 뒤 validate가 `review source changed`, `timeline source changed`, `expected action source changed`를 반환했다. 해결 확인.
- 1회차 SpriteFrames 수집 후 변경 재현: `.tres` 변경 뒤 새 prepare가 `timeline source changed`로 거부했다. 해결 확인.
- 1회차 1ms·garbage-phase·한 샘플 재현: `incomplete runtime phases or tick counts`와 `invalid runtime sample`로 거부했다. 해결 확인.
- 실제 `timeline-r03.json`: 원본 프로젝트 기준 `timeline_errors=[]`, 모션120종, sources133개. 네 캐릭터 모두 차지 준비 상태1개와 side/up/down 각각 최소12·최대90tick 해제6개를 갖는다.
- 실제 최소 차지 해제 phase_ticks는 `[12,5,21]`, 최대 차지는 `[12,5,39]`이다. `_release_charge()` 호출을 통해 실제 늘어난 회복 길이가 반영됨을 코드와 결과 양쪽에서 확인했다.

## 남은 발견사항

### P2 — 단계 순서가 뒤집혀도 단계별 개수만 맞으면 통과

- 코드: `timeline_errors()`는 `Counter`로 phase별 샘플 수를 대조하지만 순서를 검사하지 않는다.
- 실제 재현: r03 복사본의 `attack_light_combo_01` 첫 변형의 `samples.reverse()`를 실행했다. 실제 순서는 회복→적중→준비가 됐지만 `timeline_errors()`가 추가 오류 없이 `[]`를 반환했다.
- 영향: 잘못 조립된 기록을 새 prepare가 받아들여 거꾸로 재생하는 자료로 검토할 수 있다. 단순 개수 검사로 준비→적중→회복의 순서를 보장하지 못한다.
- 필요 수정: 각 공격과 점프에 기대 단계 배열을 만들고 개수뿐 아니라 전체 연속 순서를 비교한다. 회복에서 준비로 되돌아가는 변형을 거부하는 자동 검사를 추가한다.

### P2 — 차지 해제 변형 여섯 개 중 하나만 남겨도 통과

- 코드: 차지 맥락 검사는 `state:attack_heavy_charge`와 `#charged-`를 포함한 ID 하나 이상만 요구한다.
- 실제 재현: r03 복사본의 네 캐릭터 차지 `variants`를 `variants[:2]`로 잘라 준비 상태와 side 최소 차지만 남겼다. up/down·최대 차지가 모두 없어졌는데도 `timeline_errors()`는 `[]`를 반환했다.
- 영향: exporter의 현재 실제 출력은 여섯 변형을 제대로 수집하지만, 이후 자료가 누락되거나 exporter가 퇴행해도 전체 검토 누락을 검사기가 찾지 못한다.
- 필요 수정: 기대 원본 공격 ID와 최소·최대 held tick 조합으로 정확한 변형 목록을 만들고 ID·phase_ticks를 대조한다. up/down 또는 최대 차지 하나가 빠진 경우도 거부하는 검사를 추가한다.

## 차지 준비 정지와 해제 공격의 분리 가능성

표현 코드의 `state_hold_frame`은 비공격 처리인 마지막 `else` 분기에서만 적용된다. `fighter.active_attack != null`인 해제 공격은 앞선 공격 분기의 `attack_frame()`을 사용한다. 따라서 준비 상태의 정지 프레임을 바꾸면서 해제 타격은 현재 공격 단계로 계속 재생하는 분리는 **기술적으로 가능**하다. 원화 전체를 힘 모으기 전용으로 다시 그리는 방법만 있는 것은 아니다.

정적 비교판도 대조했다. 묘령은 이전에 전체16프레임을 열었고 이번에는 나비·유란의 차지 비교판도 각각 직접 열었다.

- 묘령: 4번(1부터 세는 번호)의 낮춘 자세를 준비 정지 후보로 삼을 수 있다. 현재 뒤쪽 킥8–10과 대기14–16까지 준비에서 재생하지 않게 만들 수 있다.
- 나비: 5–6번의 힘을 낮추고 팔을 당긴 자세가 준비 후보이며, 9–12번의 뻗은 발톱 타격은 해제 쪽에 둘 수 있다.
- 유란: 7번 전후의 몸을 낮추고 꼬리를 올린 자세가 준비 후보다. 실제 정지에서 피하기·쓰러짐과 충분히 구분되는지는 재생 확인이 필요하다.

이는 수정 시안 후보 검토이며 실제 변경이나 사용자 승인을 대신하지 않는다. 각 후보를 정상·느린 재생에서 유지시켜 준비로 읽히는지 별도로 확인해야 한다. 코드 분리가 가능하다는 사실만으로 의미 통과를 선언하지 않는다.

또한 준비 상태 문제를 해결해도 해제 공격 방향 문제는 남는다. 예를 들어 묘령 차지 원화의 완성 타격은 주로 수평 킥인데 같은 시트가 side/up/down 차지에 공유된다. 각 방향의 기대 강공격과 현재 원화가 맞는지는 세 방향 해제 변형마다 검토해야 한다. 같은 시트의 프레임 선택만으로 충분하지 않으면 방향별 시안 또는 표현 ID 분리를 담당 역할에 돌려야 한다. 피해·판정 시간을 그림에 맞추어 바꾸지 않는다.

## 1회차 배치 JSON 지적의 적용 범위 정정

1회차에서 언급한 `forest_arena/data/character_display_layout_v01.json` 직접 읽기는 **구현 작업 폴더의** `local_fighter_presentation.gd`에 존재한다(`DISPLAY_LAYOUT_PATH`, `display_layout()`, 약91행 FileAccess 및148행 호출). 그러나 r03을 생성한 **원본 프로젝트의** 표현 코드는 이 JSON을 읽지 않고 manifest에서 크기·기준 위치를 읽는다.

따라서 원본 r03에 이 JSON hash를 필수로 요구하는 지적은 철회한다. 구현 작업 폴더의 해당 표현 버전을 실제로 통합할 경우에만 이 JSON이 새 실행 입력이 되므로 fingerprints에 포함해야 한다. 두 checkout의 차이를 구분하지 않은 1회차 보고의 범위를 여기서 바로잡는다.

## 한계

- 이번 결과는 시간표·코드·정적 비교판 확인이다. 브라우저의 정상·느린·반전·소형 재생이나 Android 실제 기기를 통과했다고 주장하지 않는다.
- 코드·공유 review·manifest·원본 runtime 자산은 수정하지 않았다. 이 보고서만 작성했다.
