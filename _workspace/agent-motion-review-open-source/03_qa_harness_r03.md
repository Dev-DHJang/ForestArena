# 모션 검토 도구 독립 QA 3회차

- 검토자: 독립 QA `review_myo`
- 검토일: 2026-10-19
- 도구 판정: **pass — 2회차 잔여 두 결함의 재현 차단과 실제 기록 확인 범위**.
- 이 결과는 그림 의미 자동 판정, 사용자 승인 또는 게임·Android 기기 검사를 대신하지 않는다.

## 실제 시간표와 이전 결함 재검사

| 검사 | 원본 `timeline-r04.json` | 구현 `integration-timeline.json` |
| --- | --- | --- |
| 해당 프로젝트 source·SpriteFrames·PNG 해시와 전체 모션 대조 | 오류0, 모션120종·source133개 | 오류0, 모션120종·source134개 |
| 첫 약연계 samples를 reverse한 복사본 | `incomplete runtime phases or tick counts`로 거부 | 같은 오류로 거부 |
| 차지 variants를 준비+side최소차지 두 개로 줄인 복사본 | 네 캐릭터 모두 `missing or unexpected runtime variant`로 거부 | 같은 오류로 거부 |
| 선택적 표시 배치 JSON 고정 | 해당 표현 코드는 읽지 않으므로 없음 | 실제 읽는 배치 JSON hash 포함 |

두 실제 파일을 읽고 `timeline_errors()`를 각각의 실행 프로젝트 루트에 대해 호출했다. 재현에는 메모리 복사본만 변경했다. 기존 두 결함이 모두 차단되는 것을 확인했다. 코드의 단계 배열 순서 비교와 required_variant_ids 전체 목록 비교가 결과에 반영된다.

`python3 -m unittest discover -s tools/forest_arena -p test_motion_action_review.py -q`는 **23개 통과**했다. 1·2회차에 다룬 원문·SpriteFrames 고정과 단계·길이·60Hz 검사는 유지된다. 새로운 교정 범위는 추가하지 않았다.

## 묘령 수정 시안 r01의 원화 교정 확인

독립 결과는 원본 작업 폴더의 `qa-drafts-myo-ryung-r01.json`에 기록했다. 각 `r01-board.jpg` 회색 alpha 합성 비교판을 실제 열어3장×16프레임, 총48프레임을 확인하고 각 원본 PNG와 비교판 해시를 남겼다. raw PNG의 투명 영역 RGB 잔여색은 렌더링된 결함으로 취급하지 않았다.

- **run:** 기존13–16의 대기 묶음이 다리 회수·보폭 확대·다음 걸음으로 바뀌어 루프 안에서 서 있는 구간이 제거됐다.16→1의 연결 및 좌우 다리 교대의 읽힘은 재생 확인이 남는다.
- **special_neutral:** 준비1–5에는 무릎 접기만 있고 적중6·8·10에 전방 킥,7·9에 회수가 들어간다.11–16은 회수·대기라 준비·회복에서 별도 킥이 나오는 기존 문제가 교정됐다.
- **ultimate:** 포획을 알리는 손 뻗기1–3, 상승4–6, 연속 킥7–8, 하강 준비9와 하강 마무리10, 회수·착지11–16으로 구간이 구별된다. 기존 하강 마무리가 회복에 놓인 문제는 원화에서 교정됐다.

세 시안의 원화 교정 자체는 확인했지만, 이번 담당은 비교판 검사이므로 전체 모션 `pass`를 선언하지 않았다. 단독 JSON의 status는 재생 확인 대기인 `blocked`이며 correction_status에 원화 교정 확인을 별도로 기록했다. 정상·느린·좌우 반전·소형 표시·실제 시간표 재생 checks는 false다. 부모 검토자가 실제 확인한 재생 결과와 결합해 판정을 마쳐야 한다.

## 변경 범위

이 보고서와 지정된 단독 시안 QA JSON만 작성했다. 시간표·구현 코드·공유 검토 JSON·manifest·게임 자산은 수정하지 않았다.
