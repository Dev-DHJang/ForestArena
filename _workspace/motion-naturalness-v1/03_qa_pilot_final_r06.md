# 대표 모션 10종 독립 QA 최종 r06

담당: `pilot_boundary_qa` / 역할 `qa`. 2026-10-23. **이번에 고정한 대표 10종은 pass**다. 전체 36종의 개발 완료나 사용자 승인을 뜻하지 않는다. 새 후보·전투 코드·manifest는 이 검토자가 수정하지 않았다.

## 확인 방법과 직접 본 범위

- `forest-arena-qa`, `docs/content/motion-action-review.md`, 원 요청, 대표 세트 기대 행위와 이전 크기/연결 수정 기록을 기준으로 했다. 이전 pass를 새 킥 r05에 재사용하지 않았다.
- `review/pilot-r04/boards/`의 10종 전체 176셀을 직접 확인했다. 자현·나비 각각 run16/jump24/약공격3종16씩이다. 자현 첫 번째 왼손은 실제 연계의 1타·3타에 함께 쓰인다.
- `review/live-pilot-r06`의 실제 정방향 줌1.50 6개 영상과 804프레임, `review/live-pilot-mirror-r06`의 실제 좌우 반전·줌0.75 6개 영상과 804프레임을 확인했다. 합계1608프레임 모두 시간순 비교판으로 직접 대조했다. 실제 MatchController·입력·지형·표현 코드와 상태 보고서를 함께 확인했으며, 두 보고서는 각각4069검사·오류0이다.
- 전체 실제 프레임 비교판은 `qa/ja-normal-*-r06-part*.jpg`, `qa/nabi-normal-*-r06-part*.jpg`, `qa/ja-hyun-mirror-small-*-r06-part*.jpg`, `qa/nabi-mirror-small-*-r06-part*.jpg`의 총56장이다. 단순 핵심 그림 6장만으로 전체 모션을 통과시키지 않았다.
- Chrome QA 화면 `qa/playback-r06.html`에서 실제 MP4 6개 묶음을 정상1배와0.25배로 각각 처음부터 끝까지 재생했다. 정방향·반전소형 두 묶음 모두 재생 중과 끝까지 재생됨의 UI 상태를 확인했다. 동작의 세부 판단은 이 UI 표본 화면만으로 하지 않고, 앞서 직접 본 전체1608프레임과 각60Hz 시간·상태를 함께 대조했다. 반전 재생 완료 화면은 `qa/mirror-normal-playback-ended-r06.png`, `qa/mirror-slow-playback-ended-r06.png`에 남겼다.
- `pilot-r04/index.html` canvas는 코드가 선택한 그림·시간의 보조 자료다. 이 canvas는 `presentation_scale`과 `body_root`를 재현하지 않으므로 표시 크기·접지는 실제 게임 캡처로 판단했다.

## 관찰

- **달리기:** 두 캐릭터 모두 좌우 다리 교대와 팔의 반대 움직임으로 대기와 구별되는 전진 달리기가 읽힌다. 반복 끝→처음과 입력 해제→idle의 연결에서 필수 재수정으로 볼 큰 몸 크기 변화·지면 이탈·발 미끄러짐을 확인하지 않았다. 자현 고정0.85배는 실제 캡처에서 머리 단위를 idle과 연결한다. 보폭 데이터81.6은 표시 주기용이며 전투 이동 속도를 바꾼 결과로 기록하지 않는다.
- **점프:** 상승·정점·하강의 접힌/펼친 다리가 구별되고, 착지 F16~23은 실제 접촉 뒤에만 나온다. 자현은 tick57 착지→tick73 idle, 나비는 tick60 착지→tick76 idle로 이어진다. 점프 속도가 바뀌는 실제 시간 순서를 확인했으며 모든 공중 자세가 이번 한 번의 점프에 반드시 표시됐다고 주장하지 않는다. 원화176셀 검토와 실제로 선택된 프레임 검토는 구분한다.
- **자현 약공격:** 왼손→오른손→왼손→한 번의 전방 킥이 구별된다. 공격하지 않는 손은 가드하며 단타 후 회수한다. 새 킥 r05는 직전 펀치의 가드에서 무릎을 들고 지지 다리를 편다. 머리 크기가 작아지는 모델 변화로 오해했던 부분은 고정 머리 단위와 자세 높이를 분리해 판단했다.
- **킥 수정 확인:** 이전 r04의 F14 깊은 웅크림→F15 급상승은 새 단일 중간 원화로 해소됐다. 정방향과 반전소형의 tick129~137에서 F13→새 F14→F15→idle이 가드와 발 기준을 유지하며 이어진다. F4~7의 단 한 번 발 뻗기와 F8 이후 회수도 유지된다. `03_qa_ja_boundaries_r05.md`의 fix는 이전 해시에 대한 유효한 기록으로 보존하고, 새 r05 해시에 이번 pass를 남긴다.
- **나비 약공격:** 왼손 전방 할퀴기→오른손 상향 할퀴기→양손 교차 후 밖으로 펼치는 X 단타가 읽힌다. 상향 공격에서 반대손 가드가 유지되고, X의 회복은 두 손을 가드로 돌린다. 최종 `body_root`에서 이전 X의 몸 중심이 옆으로 흐르는 문제는 재현되지 않았다. 정방향과 반전소형 모두 얼굴·손·발·꼬리가 잘리지 않는다.
- 작은 표시에서는 손가락 세부보다 동작 실루엣을 중심으로 판단했다. 전진/점프/단타/양손 X와 두 캐릭터를 구분할 수 있었다. 배경과 겹쳐 얼굴이나 몸 전체가 사라지는 필수 문제는 이번 시험에서 발견하지 않았다.

## 결과와 한계

`review/pilot-r04/motion-review.json`에 10종별 기대 행위·직접 본 관찰·필수6항목·실제 영상/상태/전체tick 비교판 해시를 기록했다. 각 `status=pass`, `reviewer_role=qa`, `approval_status=pending`이다. 후보 검토 양식의 `materials`는 도구가 정한 전체셀/시트 두 항목을 유지하고, 추가 실제 재생 자료는 `actual_playback_materials`와 `sources`로 연결했다.

`review_motion_actions.py validate --require-pass`는10pass, `MOTION_ACTION_REVIEW: PASS (record integrity only)`다. 이 도구 결과는 기록/해시의 완전성 확인이며 그림 의미를 자동 증명한 결과로 쓰지 않는다.

이번 pass는 대표10종의 모션 검토다. 나머지26종, 이전 새5모션의 별도 승인, 사용자의 모션별 명시 승인은 완료하지 않았다. runtime PNG/manifest 등록도 승인 전에는 하지 않는다. Android 실제 기기가 없어 엄지 조작성·가독성·기기 성능·중단/복귀를 기기 통과로 기록하지 않는다. 촬영 프로세스가 OS 초점 일시정지 콜백을 제외한 점도 실제 Android 생명주기 검사의 대체가 아니다.

원본 PNG는 정방향804장/반전소형804장의 모든 RGBA 프레임 해시가 일치하는 무손실 아카이브로 보존한 뒤 정리할 수 있다. 이 QA에서 필요한 전체 비교판과 경계 검토를 모두 만들고 확인했으므로 추가 원본 PNG 크롭 대기는 없다.

## 고정한 후보 PNG

| 캐릭터 | 모션 | SHA-256 |
| --- | --- | --- |
| ja-hyun | attack_light_combo_01 | `7fc8bcb8e3de49ab25cde2e0184fee53d99525803fc408849120db8caf887982` |
| ja-hyun | attack_light_combo_02 | `c9a885dabc3cbc2daa732f0043d46bd3fcf32f93a7c0dc7ee9b7d656bf1651fd` |
| ja-hyun | attack_light_combo_04 | `7a24de2b900beb63ed9e2ba2f0e29b0700dec8aeb506f9d24ada3e295e99f48f` |
| ja-hyun | jump | `7b417ed37f113b828c1e0d67b1be00258a8756d4c2bf7a5cbcc9e0ed5f625ac1` |
| ja-hyun | run | `08a3faa2609ff87aebf8623b95a40fcfacedb88cc8c9cc85d1f2f8b148d80cf3` |
| nabi | attack_light_combo_01 | `8758aa263ae6a48076234a7a672d00b911a441249d54afd5bbadc94e71612844` |
| nabi | attack_light_combo_02 | `926bd0821bfba73877e6fb039a04df323fa5ff139311643fbb8c105394e97cd5` |
| nabi | attack_light_up | `6d0d74fdfecaf162838ee4222f57e81efe749878ed3fba946de30cbbde9c2b50` |
| nabi | jump | `8e5c530cc6eea933f9f4a7c8b0e8b01c1427efc3e002343f575b87352c60cf5d` |
| nabi | run | `25b18202ccbad8a557735256d576f890fffbb3ec4e1dc20d4215c490d28a5ef8` |

## 실제 촬영 보고서 해시

- `live-pilot-r06/state-report.json`: `6e2c1cc46d7ec821ae194e45b0794f3aef2701b52f04af3ad805bbd8617552d0`
- `live-pilot-mirror-r06/state-report.json`: `e2c602926c125b591e825fa4f923117d98799ebc0d40bdcde4dbc6b20ac6612a`
