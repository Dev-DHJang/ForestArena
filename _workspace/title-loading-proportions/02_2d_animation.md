# 캐릭터 머리 비율 통합 — 자현 기준 재검토

상태: **머리 가로폭을 보정한 표본 3종 준비, 사용자 검토 대기**. 게임의 캐릭터 PNG·SpriteFrames·manifest·전투 시간은 변경하지 않았다. 기존 승인 기록과 최신 묘령 재제작을 합치되 이전 대화의 승인을 새 이미지의 승인으로 옮기지 않는다.

## 실제 검토 파일

- [현재 게임 / 머리 폭 수정 후보 비교](character-review/comparison-before-after.png)
- [실제 128px 셀·밝은 바탕](character-review/same-size-128-light.png) · [어두운 바탕](character-review/same-size-128-dark.png)
- [4배 확대·밝은 바탕](character-review/same-size-4x-light.png) · [어두운 바탕](character-review/same-size-4x-dark.png)
- 묘령: [16포즈](character-review/myo-ryung/idle-review-4x4.png) · [8 FPS GIF](character-review/myo-ryung/idle-review.gif)
- 나비 새 r02: [16포즈](character-review/edits-r02/nabi/idle-head-width-review-4x4.png) · [8 FPS GIF](character-review/edits-r02/nabi/idle-head-width-review.gif) · [측정선](character-review/edits-r02/nabi/first-pose-measurement.png)
- 유란 새 r02: [16포즈](character-review/edits-r02/yu-ran/idle-head-width-review-4x4.png) · [8 FPS GIF](character-review/edits-r02/yu-ran/idle-head-width-review.gif) · [측정선](character-review/edits-r02/yu-ran/first-pose-measurement.png)
- [기존 최신 묘령 31종 전체 비교](character-review/existing-candidates/myo-ryung/31-motion-overview.png)

최신 묘령 idle은 기존 파일 내용 그대로 재사용했다. 나비·유란의 기존 표본은 세로 비중만 맞고 머리의 가로 인상이 여전히 컸다. 그래서 **내장 이미지 편집 도구**로 나비 약20%, 유란 약13%의 머리 가로폭 축소를 요청했다. 머리 높이·목 연결·몸통·팔·다리·신발·자세·16포즈·그림체·고유 외형은 보존하도록 지정했다. 정확한 프롬프트·입력·도구 출력 경로는 각 `edits-r02/<캐릭터>/request.json`, 편집 원본 PNG는 같은 폴더 `idle-head-width-source.png`에 있다. 기존 승인 파일과 생성 원본은 보존했다.

표시용 128px 배치는 프로젝트의 기존 `motion_sheet_regions.py`로 16포즈를 분리하고, 모션 안에서 하나의 고정 배율로 배치했다. Python으로 머리나 몸의 픽셀 비율을 보정하지 않았다. 전체 스프라이트를 추가로 줄여 머리 문제를 숨기지 않았다. 현재 자현은 이전 비율 작업 기준 자현 idle과 SHA-256이 같으며 비교 셀은 전부 128×128, 표시 배율은 1.0이다.

## 머리 너비·높이 측정

측정 대상은 첫 대기 자세의 **두개골에 붙어 있는 머리 덩어리**다. 귀·묶은 머리·늘어진 머리카락·리본은 제외한다. 신체 높이는 정수리부터 발바닥, 머리 높이는 정수리부터 턱이다. 회전이 있는 그림에서 눈으로 찾은 위치이므로 정밀한 3D 관절 측정이 아니다.

| 캐릭터 | 머리 너비 | 자현 대비 너비 차이 | 머리 높이 | 자현 대비 높이 차이 | 신체 높이 |
| --- | --- | --- | --- | --- | --- |
| 자현 기준 | 약27px | 기준 | 26px | 기준 | 72px |
| 최신 묘령 재사용 | 약28px | 약3.70% | 25.5px | 약1.92% | 72px |
| 나비 새 r02 | 약28.27px | 약4.71% | 약26.76px | 약2.94% | 72px |
| 유란 새 r02 | 약26.53px | 약1.75% | 약25.39px | 약2.35% | 72px |

- 자현 머리cap x=62~89, 최신 묘령 x=60~88. [자현 격자](character-review/ja-hyun/first-pose-grid.png) · [묘령 격자](character-review/myo-ryung/first-pose-grid.png).
- 기존 나비는 x=55~89의 약34px, 유란은 x=62~93의 약31px로 표시해 가로폭 수정 대상으로 판단했다. 이 파일은 `nabi/`, `yu-ran/`과 `comparison-before-after-r01.png`에 남아 있다.
- 새 나비 분리 원본: 머리cap x=101~176, 정수리y=29·턱100·발바닥220, 고정 배율72/191.
- 새 유란 분리 원본: 머리cap x=111~181, 정수리y=31·턱98·발바닥221, 고정 배율72/190.
- 수치·배율·SHA-256은 [edits-r02/report.json](character-review/edits-r02/report.json), 선택 파일은 [review-selection.json](character-review/review-selection.json)에 기록했다.

첫 대기 자세의 머리 가로·세로 크기와 신체 높이 목표를 만족하는 검토 후보로 준비했다. **모든 프레임의 머리 너비·어깨 너비·팔·다리 관절 길이가 10% 이내라는 증거로 확대하지 않는다.** 이전 세로 구간 측정은 `measurements.json`과 `provenance/`에 보존하지만 새로 편집한 나비·유란의 몸통/다리 측정값으로 옮기지 않았다. 몸통·팔다리 관계와 그림체는 전체 포즈의 별도 시각 검토가 필요하다.

확대 비교판에서 새 나비·유란의 머리 가로 인상이 줄었고, 인간형 얼굴·손발·의상·고유 색이 유지되는지 확인했다. 묘령의 긴 귀2개와 리본, 나비의 고양이 귀·큰 꼬리·발톱, 유란의 둥근 귀·갈색/흰색 줄 꼬리·청록 장식도 확인했다. 이는 제작자 시각 확인이며 모션 전체 외형 승인이나 실제 기기 통과를 뜻하지 않는다.

## 전체 90종과 다음 순서

- [baseline-90.json](character-review/baseline-90.json): 현재 HEAD, manifest·외형 계약, 묘령31·나비29·유란30개의 PNG·SpriteFrames와 자현30개의 확인값, FPS·loop·프레임 수를 고정했다.
- [scope-90.json](character-review/scope-90.json): 각90종의 기존 실행 파일과 후보·상태를 연결한다. 묘령31종, 나비 idle, 유란 idle의 후보33종이 있으며 나비28·유란29의 **57종은 전체 모션 후보가 아직 없다**.
- 최신 묘령31종의 기존 검토 PNG·GIF도 `existing-candidates/myo-ryung/`에 복사했다. 과거 idle·run·attack_air_heavy 3종 승인과 나머지28종 검토 대기를 파일 확인값에 묶어 보존했다. 이번 머리폭 재검토의 승인으로 간주하지 않는다.
- 이번 표본 재검토 후 묘령 → 나비 → 유란 순서로 이어간다. 각 모션의 명시 승인 뒤에만 기존 논리 ID와 실행 경로로 반영하고, 출처와 확인값을 갱신한다. 16프레임·FPS·loop·발 기준·전투 판정·공격 시간은 유지한다.

게임 반영을 남긴 근거는 [2D 애니메이션 스킬](../../.agents/skills/forest-arena-2d-animation/SKILL.md)의 명시 규칙이다: **“모션별 사용자 명시 승인 전에는 런타임 경로·manifest에 쓰지 않고, 승인되지 않은 모션은 런타임 파일을 생성하지 않는다.”** 이 작업의 구현 승인은 승인되지 않은 개별 모션 이미지의 외형 승인으로 해석하지 않았다.

## 재검사

`HEAD_WIDTH_EDIT_REVIEW_R02`

- `python3 _workspace/title-loading-proportions/character-review/stage_edits_r02.py`: PASS. 새 편집2종·분리32포즈, 실제 RGBA alpha0~255, 512×512 시트·128px셀16개, 각각16개 서로 다른 프레임, 모션별 고정 배율, 첫 자세 머리 높이/너비 차이10% 이내·신체72px 확인.
- `python3 _workspace/title-loading-proportions/character-review/verify_review.py`: PASS. 대상90·자현30의 기존 PNG·SpriteFrames·manifest·외형 계약 확인값 유지, 현재 선택 표본의 해시·RGBA·16프레임 검증.
- GIF2개 각16프레임, 120/130ms 번갈아 총2,000ms·평균8 FPS·반복. 기존 게임 FPS/loop는 수정하지 않았다.
- 새 투명 원본·실제 alpha 합성 비교판·측정선 이미지를 열어 검토했다. 과거 승인 표본과 새 편집 표본을 별도 기록으로 보존했다.
- Android 실제 기기·게임 내90종 적용·개별 모션 전체 승인: 미완료.
