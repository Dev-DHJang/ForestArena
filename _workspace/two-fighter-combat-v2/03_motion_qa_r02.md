# 전투 모션 독립 검토 2회차

- 담당: 독립 QA `final_motion_review`. 생산 코드·PNG를 수정하지 않았다.
- 최종 결과: **36개 pass, fix/redo/blocked 0개**. 범위는 고정된 자현·나비 실사용36개(기존 승인31개 + 신규 후보5개)다.
- 신규5개는 계속 **사용자 승인 대기**다. QA 통과는 모션별 사용자 승인을 대신하지 않으며 승인 전 runtime·manifest 등록을 허용한 기록이 아니다.
- 실제 Android 기기 검사와 전체 경기의 모든 상황을 확인한 기록이 아니다.

## 검토 자료와 방법

수동 재검사 `M-MOTION-FINAL-02`: 1회차에서 직접 본 모든36개·각16프레임 비교판은 현재 해시와 모두 같다. 원화 관찰은 `qa/final-motion/r01-observations.json`에 보존했다. 변경된 표현 코드와 새 timeline을 독립적으로 실행하고, 새 게임 순서·상태 변형을 원화·재생 화면과 다시 대조했다. 변경 전 코드의 통과를 새 코드에 자동 이전하지 않았다.

- 최종 전체 양식: `review/motion-review.json`. 기대 행위·근거 문서·PNG/tres·표현/전투 코드·검토 자료 해시, 모션별 구체적 관찰과6개 확인 항목을 기록했다.
- 기준 timeline: `review/timeline.json`, SHA-256 `d14a9887f6e3ba9f5ca2b17bc0c00086eb1210fe7be4cd777cbef344b3fa35c9`.
- QA 독립 실행: `qa/final-motion/timeline-r02.json`. 부모가 만든 최종 timeline과 **전체 바이트·sources·motions가 같다**.
- 정상1배·느린0.25배, 원화 FPS와 게임 기록 순서, 좌우 반전·96px 모아보기와 작은 표시를 Chrome에서 보았다. 화면 표본과 전체 정지 비교판을 함께 대조했다. 동영상의 연속 모든 화면을 사람이 실시간으로 지켜본 검사로 확대하지 않는다.
- 실제 표현 코드와 효과: 최종 `review/rendered/`의8개 MP4·무손실 MKV·6장 JPG를 대조했다. 최종 렌더 메타데이터의 production source 해시는 모두 현재 파일과 일치하고 errors는0개다. `qa/final-motion/r02-current-fx.jpg`는8개 첫 활성 화면을 모은 추가 관찰 자료다.
- 실제 나비 특수: `review/live-special/`의 success/whiff/blocked 각 MP4·MKV·6장 JPG, `state-report.json`을 함께 보았다. `live-success-strike22-25.jpg`는 무손실 영상의 실제 단타4프레임이다.
- `review/rendered/qa-grid.html`과 `review/live-special/qa-grid.html`은 같은 영상을 동시에 재생하는 QA용 페이지다. 정식 JSON의 sources에 추가 자료42개의 해시도 고정해 변경을 탐지한다.

## 1회차 수정6개 재검토

| 대상 | 최종 확인 |
| --- | --- |
| 자현 jump | 공중 하강은0기준10, 사람F11만 유지한다. 양발을 딛는 F13–16은 실제 착지 뒤0.25초에 표시한다. |
| 나비 jump | 하강은F11–12만 사용하고, F13–16의 양발 착지·회복은 실제 착지 뒤에 나온다. |
| 자현·나비 knock_down | 추가 `state:landing-down-18` 변형은18tick=300ms에 누운 F13–16을 표시한다. 기존2초 고정 원화 재생과 구분해 선택·검토했다. |
| 자현·나비 wake_up | 추가 `state:wakeup-protection-12` 변형은12tick=200ms에 누움→손/무릎 지지→일어남→마지막F16을 끝낸다. IDLE로 상태가 바뀐 뒤에도 보호 시간이 남으면 시각 회복을 이어가고, 이동·점프·공격은 원래 규칙대로 전환된다. |

독립 실행 `godot --headless --path . --script res://tests/two_fighter_presentation.gd`는 **TWO_FIGHTER_PRESENTATION: PASS**, 종료0이었다. 실제 바닥 접촉, 다운18tick·기상12tick, IDLE 전환 뒤 시각 회복, 이동 시 RUN 전환, 공중/착지 프레임 분리와 전투 snapshot 불변을 대조한다. 2초 고정 상태 재생만으로 실제 상태 수명을 통과시키지 않았다.

## 추가 자료4개 확인

- 자현 지상 강 `special_neutral`: 준비 때 긴 파랑 천을 전방으로 내밀고 활성 뒤 팔을 당겨 회수한다. 별도 긴 리치 효과는 얼굴 뒤에서 이어지고 회복 때 사라진다.
- 양쪽 `attack_air_light`: 발을 딛지 않은 전방 단타→회수와 긴 리치 효과가 구분된다. 자현은 파랑 천, 나비는 전방 세 줄 손톱 흔적이며 회복 때 사라진다.
- 나비 `special_side` 성공: tick9–21 run으로 돌파, x600→864(시작 상대 x800 뒤64), tick22 facing−1로 돌아서 상대쪽 단타, HP105→93 한 번, tick26 회복·46 정지다. 실제 strike tick22–25 네 장에서 왼쪽으로 뻗는 손톱과 상대 위치를 직접 보았다.
- 빈 이동은 x600→920의320 이동 뒤 상대 HP가 유지되고, 벽 차단은 x600에서 이동 없이 실패·회복하며 상대 HP가 유지된다. 목표를 지나친 뒤 계속 추적하는 표시를 관찰하지 못했다.

## 신규5개와 외형

나비 공중 강 r04n02는 낮게 준비한 같은 팔이 가슴앞·대각위·머리위로 이어지고 F8–10을 짧게 유지해 예비 r02의 팔 교체가 사라졌다. 자현 킥은 한발지지·앞발펴기·회수이며 목도리 공격과 구분된다. 자현 공중 강은 위에서 아래로 단 한 번 내린 뒤 어깨로 회수한다. 자현 특수는 좌·우·위만 표시하고 마지막 벌림이 보인다. 나비 약2는 반대손을 얼굴 곁에 둔 한 팔 상승이다.

귀·꼬리·파랑 천 또는 보라 손톱·옷색·인간형 손발을 대조했다. n02의 이웃 셀 조각·팔/귀/천 수직 절단은 관찰하지 못했고, 최신 가는 효과가 얼굴을 가리지 않는다. 반복 프레임과 끝 자세 유지 자체를 결함으로 처리하지 않았다.

## 기록 검사

`review_motion_actions.py validate`에 원본 catalog/scope와 외부 scope SHA-256, `--require-pass`를 전달했다.

```text
Review decisions: {'pass': 36}
MOTION_ACTION_REVIEW: PASS (record integrity only)
exit_code: 0
```

이는 기록의 완전성과 해시 일치를 검사한 결과이며 그림의 의미 판단은 위 독립 눈검토 기록에 따른다. `./scripts/verify-docs.sh`는1회차 기록 뒤 PASS였고 최종 기록 뒤 다시 실행한다.
