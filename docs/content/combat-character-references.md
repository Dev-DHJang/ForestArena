# 대전 모션용 대표 이미지

대표 이미지는 같은 캐릭터의 모션마다 얼굴·체형·의상·표시 크기가 달라지지 않게 만드는 제작 기준이다. 외형 규칙은 [캐릭터 외형 계약](../contracts/character-appearance-v01.json)이 최종 기준이며, 대표 이미지가 이를 바꾸지는 않는다.

## 세트와 크기

자현·묘령·나비·유란 각각에 오른쪽을 향한 약한 3/4 각도 대전 기본 자세(`combat`), 중립 정면(`front`), 오른쪽 측면(`side`), 후면(`rear`)을 준비한다. 기존 승인 콘셉트를 직접 참조해 정면 구성 모델을 먼저 만들고, 같은 모델을 기본 자세·측면·후면으로 바꾼다. 정면 구성 모델은 비율·얼굴·의상 배치의 1차 참조, 승인 콘셉트는 정체성·외형 계약 확인의 참조로 함께 첨부한다. 비전투 개성 콘셉트나 과거 미승인 모션으로 기준을 대체하지 않는다.

- 각 PNG는 1024×1024, 실제 투명 RGBA이며 문자·효과·바닥 그림자가 없다. 귀·꼬리·리본까지 잘리지 않아야 한다.
- 중립 자세의 머리 본체 정수리부터 가장 낮은 발바닥까지 640px, 발바닥 기준 y=896으로 맞춘다. 귀·돌출 머리카락·꼬리·리본은 몸 높이에 포함하지 않는다. 두 발 사이 중심은 x=512이다.
- 캐릭터 고유 체형과 약 3등신 비율을 유지한다. 대전 자세는 중립 자세와 같은 머리 크기로 맞추며, 웅크려 낮아진 몸을 늘리지 않는다.
- 정면·측면의 몸 높이/머리 높이 비율은 2.6~3.4 안에서 확인하고, 정면 대비 머리 높이 차이가 8%를 넘으면 재검토한다. 이는 시각 비교를 보조하는 수치이며 기준점을 옮겨 실패를 통과시키지 않는다. 후면의 턱 위치는 가려진 구조의 추정값(`chin_estimated: true`)으로 표시한다.
- 생성 원본과 신체 기준점 좌표를 보존하고, 그림 전체에 한 번의 균일 배율과 이동만 적용해 공통 캔버스에 배치한다. 신체 부위를 따로 늘이거나 그림을 다시 그리는 수정은 이미지 생성 도구로 한다.

## 제작·검토·등록

시안과 `reference.json`은 `_workspace/combat-character-references/`에 둔다. 독립 QA는 네 각도의 얼굴·머리·팔다리 비율, 의상, 종 특징과 금지 외형을 직접 비교하고 128px 크기와 좌우 반전에서도 확인한다. 파일 규격 검사만으로 시각 QA를 통과시키지 않는다.

각 캐릭터 4장 세트의 QA pass와 사용자 명시 승인 뒤에만 `assets/character/<character-id>/reference/v01/`에 PNG·`reference.json`을 등록한다. manifest에는 `type: motion-reference`로 각 이미지의 ID·경로·해시·각도·버전·세트 경로와 원본 콘셉트 ID·출처·권리를 기록한다. 기존 대표 콘셉트와 CharacterData·게임 표시 배율은 유지한다.

이 폴더는 제작 도구가 실제 파일로 읽는 참조다. 각 `reference/`의 `.gdignore`로 Godot 가져오기 대상에서 제외한다. 대전 화면이 읽는 런타임 이미지나 리소스 카탈로그에 연결하지 않는다.

`reference.json`에는 세트 버전·상태, 원본 콘셉트 ID·해시, 외형 계약 해시, 각 이미지의 원본/배치본 경로·해시, 머리·턱·발 기준점, 배율·이동과 실측 크기를 기록한다. `approval`과 `qa` 각각에 상태·기록 경로·대상 이미지 해시를 둔다. 해당 JSON 기록에도 `character_id`, `reference_version`, `decision`(사용자 승인 `approved`, QA `pass`), `image_sha256`, 실제 승인 발언 또는 검토 관찰인 `evidence`를 기록해 대조한다. 제작 시작 승인을 이미지 채택 승인으로 기록하지 않는다.

## 이후 모션 제작

### 승인된 v01 세트

2026-10-29 사용자가 네 세트를 채택했다. 아래 세트는 각각 PNG4장과 사용자 승인·독립 QA의 대상 해시를 연결한다.

| 캐릭터 | 정식 참조 세트 |
| --- | --- |
| 자현 | [ja-hyun/reference/v01/reference.json](../../assets/character/ja-hyun/reference/v01/reference.json) |
| 묘령 | [myo-ryung/reference/v01/reference.json](../../assets/character/myo-ryung/reference/v01/reference.json) |
| 나비 | [nabi/reference/v01/reference.json](../../assets/character/nabi/reference/v01/reference.json) |
| 유란 | [yu-ran/reference/v01/reference.json](../../assets/character/yu-ran/reference/v01/reference.json) |

### 제작 시 확인

1. 해당 캐릭터의 등록된 `reference.json`을 읽고 승인 상태·파일 해시·콘셉트·외형 계약을 확인한다. 승인 세트가 없거나 파일이 바뀌었으면 기준 복구 또는 재승인 전 새 모션 제작을 멈춘다. 기존 승인 모션의 재생은 영향을 받지 않는다.
2. `combat`과 필요한 각도의 PNG를 이미지 생성 입력에 **직접 첨부**한다. 파일 경로나 설명만 프롬프트에 적는 것으로 대신하지 않는다. 얼굴 특징·머리 모양·의상·색·체형은 고정하고, 외형 계약이 허용하는 자세·표정과 머리카락·귀·꼬리·리본의 후속 움직임만 바꾼다.
3. 모션 제작 기록에 세트 경로·버전·실제로 첨부한 이미지 해시와 최종 프롬프트를 남긴다. 몸 기준 크기를 사용하고 귀·꼬리를 포함한 전체 외곽에 맞춰 프레임마다 확대·축소하지 않는다. 기존 128px 셀·발 기준점과의 변환은 모션 전체에 공통으로 기록한다.
4. 전체 프레임·재생을 대표 이미지와 비교한다. 웅크림·회전·원근 때문에 바뀐 외곽 크기를 체형 변화와 구분한다. [모션 행위 검토](motion-action-review.md)의 독립 QA·모션별 사용자 승인은 계속 적용한다.

## 검사

`python3 tools/forest_arena/combat_reference.py validate --reference <reference.json>`은 PNG·원본·계약 해시, 투명도·여백·기준점·크기를 확인한다. `--require-approved`는 사용자 승인 기록과 승인 대상 해시도 요구한다. 이 검사는 외형의 일관성을 눈으로 확인하는 QA를 대신하지 않는다.

`python3 tools/forest_arena/test_combat_reference.py`는 실패 사례와 실제 등록된16개의 manifest→참조 세트→PNG→승인/QA 연결도 확인한다. 예를 들어 자현 제작 전에는 `python3 tools/forest_arena/combat_reference.py validate --reference assets/character/ja-hyun/reference/v01/reference.json --require-approved`를 실행한다.

이름 있는 수동 재검사: **대표 이미지 다각도 비교**, **128px·좌우 반전 식별**, **승인 참조 첨부 확인**. Android 실기기 확인을 수행하지 않았으면 기기 통과로 기록하지 않는다.
