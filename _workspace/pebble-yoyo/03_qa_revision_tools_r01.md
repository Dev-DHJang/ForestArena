# 수정 모션 후보 검증·등록 도구 독립 검토 r01

## 결과와 범위

2026-11-02 현재 변경분의 정적 검토 결과 `pass`. 수정이 필요한 도구 결함을 발견하지 않았다. 새 캐릭터 시안과 나비 idle 보정의 시각 통과·채택 여부는 이 기록의 범위가 아니다. 후보 다섯 개는 새 실제 자료를 직접 검토한 뒤 `review-r04`에서 판정한다.

## 검토한 동작

- `layout_only_source()`는 현재 등록된 논리 ID 하나와 같은 캐릭터·모션만 허용한다. PNG는 원본·후보·양쪽 선언 해시가 모두 일치해야 하고 SpriteFrames 텍스트는 정확히 한 PNG 참조 경로 외에는 동일해야 한다. 프레임 수·열·셀·시간·FPS·반복·발 기준점·단계·정지·출시 시점은 기존 고정 필드 비교를 유지한다.
- `frame_anchors`는 `body_root`를 제외한 프레임별 사전을 비교하므로 손·무기·천 앵커의 추가·삭제·수정은 거부한다. 먼저 호출되는 `layout()`가 배열 길이와 각 프레임 사전, 알려진 앵커만 허용하며 몸 기준점은 bool을 제외한 유한 셀 좌표로 제한한다. 배율은 유한 양수이고 배율·몸 기준점 모두 동일하면 후보를 거부한다.
- 승인 PNG/SpriteFrames는 검토 필수 해시에 포함된다. `layout_only`는 여전히 `_workspace`의 미승인 후보이고 등록 자산 재사용 처리로 우회하지 않는다. runtime 소비자 노출 금지도 유지된다.
- 소비자인 `local_fighter_presentation.gd`에서 `body_root`가 그림 위치만 보정하며 좌우 반전 부호도 적용됨을 대조했다. 보정 후 실제 발·몸통 위치의 연속성은 별도 모션 QA가 필요하다. 메타데이터가 유효하다는 사실로 이를 통과시키지 않는다.
- 등록기의 `DISPLAY_FIELDS`에 장비 네 단계 필드가 추가되어 후보의 `equipment_phase_frame_ranges`를 보존한다. 등록 계획은 최신 독립 검토 pass와 정확한 카탈로그·범위 해시를 먼저 요구한다.
- 작업용 `register_approved_motions.py`는 표준 등록기의 `main`을 호출하는 얇은 별칭이다. 기본 계획은 파일 쓰기가 없고 `--review`는 필수다. `--install`은 모든 모션의 명시 사용자 결정, 계획·범위·QA·출력 해시를 먼저 확인한다. 승인 확인 전 백업 폴더도 만들지 않는다. 설치 직전 계획·출력 전상태를 다시 대조한다. 예전 r02 전용 경로가 남은 별도 등록 동작은 없다.
- 배율/몸 기준점 후보도 버전 PNG를 새 경로에 복사하는 표준 등록 절차를 따른다. 픽셀은 동일하며 기존 PNG를 덮어쓰지 않고 기존 논리 ID·SpriteFrames 소비자 경로를 유지한다. 변경 전 manifest 내용은 등록 이력과 백업에 남는다.
- 문서의 허용 범위가 코드와 일치한다. 이 도구 검토는 사용자 모션 채택을 대신하지 않는다.

## 확인한 검사 증거

`revision-motion-tools-r02.log`를 직접 읽어 `Ran 95 tests in 6.491s` / `OK`를 확인했다. 새 검사 세 개는 몸 기준점만 변경 허용, 다른 앵커 변경 거부, 잘못된 좌표 거부를 다룬다. 추가 등록 회귀는 픽셀 보존과 승인 없는 설치 시 쓰기 없음, 임시 검사 승인 후 보정 보존을 확인한다. 기존 검사에는 PNG·시간·발 기준점·SpriteFrames 변조 거부 및 승인 해시 변조 거부도 있다. 동일 코드의 통과 검사를 이유 없이 재실행하지 않았다. 이 검토에서 runtime/manifest나 생산 중 후보는 수정하지 않았다.

## 남은 조건

새 다섯 후보의 실제 기록, 승인 idle/jump와의 정확 모델 비교, 진입 직전·종료 직후와 전체 프레임, 정상·느린·반전 재생을 아직 검토하지 않았다. 나비 idle의 이미지·시간 보존 및 전체 idle 프레임에서 요요 연결도 후보 자료가 준비된 뒤 판정한다. 실제 Android 실행 결과는 이 기록에 없다.

## 검토 파일 SHA-256

```json
{
  "tools/forest_arena/motion_review_candidates.py": "8a5372f535f33462086666693d434146d37ae195aed7ec919a110cc924328e79",
  "tools/forest_arena/motion_layout.py": "64ef966a8887211c7b3cf68b5f6bf082cd621fe34cbc43bece22aa52a82235c5",
  "tools/forest_arena/register_motion_candidates.py": "2f6d6b8001f9404ec1beb380c32dadd6042237dea64a8d3dbbf89ba63eb32309",
  "_workspace/pebble-yoyo/register_approved_motions.py": "a3806f1847ed37a3e860f452ae763ff59e3b1a4dc298492889b9aabcd05f2e7f",
  "tools/forest_arena/test_motion_action_review.py": "6f96b511ab92c6df8b913f805600cfd375020dd17956b7b36baabc0ab9fa2c60",
  "docs/content/motion-action-review.md": "c6c7bc5aa2ebe985425a61cafd76bf37d75db75c84446acb9e5093cdbfb4e259",
  "build/verification/pebble-yoyo/revision-motion-tools-r02.log": "24f99f0a108d3a1722dbede635378269b32b2d2e1cec6e1aa3585a6a9798bc6c"
}
```
