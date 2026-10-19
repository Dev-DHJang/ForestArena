# 모션 검토 도구 독립 QA 4회차

- 검토자: 독립 QA `review_myo`
- 검토일: 2026-10-19
- 범위: 3회차 뒤 추가된 반복 모션2주기 기록과 PNG 전용 디코딩, 관련 테스트만 확인했다. 원화·수정 시안·다른 기능 검토는 추가하지 않았다.
- 코드 판정: **pass**. 단, 이전 integration 시간표는 새 규칙에 맞춰 다시 수집해야 한다.

## 실행 결과

`python3 -m unittest discover -s tools/forest_arena -p test_motion_action_review.py -v` — **25개 모두 통과**.

### 반복 모션2주기

- Godot exporter는 manifest의 loop가 true인 상태를 `ceil(16 / fps × 60) × 2` tick 동안 수집한다. Python 검사도 동일한 식으로 기대 sample 수를 계산한다.
- 현재 idle8fps는240tick, run12fps는160tick이다. 비반복 상태120tick과 점프 단계20+12+20+16은 그대로다.
- 추가 테스트는12fps 반복 상태에서 기존120samples를 거부하고160samples를 수용하는지 확인한다. 단계·순서·60Hz 검사는 함께 적용된다.
- 별도로 현재 구현 작업 폴더의 기존 `integration-timeline.json`을 검사했다. 이 파일은 네 캐릭터 idle/run이 아직 각각120samples여서 새 검사기가8건의 `incomplete runtime phases or tick counts`로 거부한다. 이는 새 검사의 정상적인 이전 자료 무효화다. 실제 완료 증거로 이 파일을 사용하려면 새 exporter로 시간표를 다시 수집해야 한다.

### PNG 전용 디코딩

- prepare는 `Image.open(..., formats=["PNG"])`로 디코더를 제한한다. 이후2048×128 크기·alpha 검사와 비교판 생성을 실행한다.
- 추가 테스트는 `.png` 이름에 JPEG 내용을 저장하고 시간표의 PNG 해시도 새 내용으로 맞춘 상황에서 `UnidentifiedImageError`로 거부되는지 확인한다. 따라서 해시 일치나 확장자만으로 다른 형식을 PNG로 받아들이지 않는다.
- 정상 PNG 준비·기록과 기존 무결성 테스트도 함께 통과했다.

## 범위와 한계

반복 모션의 실제 행위가 자연스러운지는 이 숫자·디코딩 검사로 판정하지 않는다. 이번에는 새 원화·시안·브라우저 재생·Android 기기 확인을 수행하지 않았다. 공유 코드·시간표·자산을 변경하지 않고 이 보고서만 작성했다.

## 최신 자료의 해소 확인

같은 날 다시 수집한 `integration-timeline-r05.json`을 구현 작업 폴더의 최신 입력과 `timeline_errors()`로 대조하여 오류0·전체120모션을 확인했다. 네 캐릭터 모두idle240samples·run160samples로 새2주기 조건을 충족한다. `integration-review-r05/motion-review.json`도120개 항목이며 기록된timeline_sha256가 새 시간표와 일치했다. 이전 통합 시간표의 재수집 필요 항목은 이 최신 자료로 해소됐다.25개 테스트는 반복하지 않았다.
