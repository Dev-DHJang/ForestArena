# 재제작 작업 상태

2026-10-17: 첫 3종에 이어 나머지 28종도 승인받아 묘령 31종을 게임에 반영했다.

- `05_myo_ryung/`의 자동 생성 반복은 중단했다. 결과를 삭제하지 않고 사용 중단 상태로 남긴다.
- 이전 idle 승인으로 새 idle이나 새 모션을 승인 처리하지 않는다.
- 선택 원본을 `01_style_reference/user-selected-style-original.png`로 복사하고 해시를 고정했다. 같은 원본에서만 뽑은 참조 두 개로 idle·run·attack_air_heavy를 내장 이미지 도구에서 각각 제작했다. 다른 시안의 그림체 이미지는 새 참조로 사용하지 않았다.
- 생성 원본·편집 이력·투명 결과는 `02_drafts/`, `03_alpha/`에 보존했다. 비교판, 4×4 시트, 128px 미리보기와 GIF는 `04_review/`에 있다. 사용한 프롬프트는 `generation-prompts-r01.json`, `edit-requests-r01.json`과 개별 배경 제거 요청에 기록했다.
- `MYO_RYUNG_STYLE_LOCK_REVIEW_R01`: 3×16 실제 다른 RGBA 프레임·파일/크기/alpha/해시·잘림 검사 통과. 같은 크기 얼굴/전신 비교와 128px 축소 검토를 수행했다. 정량 측정은 머리와 대기 자세 높이에 한정하고 모든 관절의 10% 일치로 확대하지 않았다.
- `./scripts/verify.sh`, `./scripts/verify-docs.sh`, 시작 파일 보존 검사 통과. 전체 검사 출력은 `verify-project.log`다.
- 위 제작·검토 시점에는 게임 파일 반영이 없었다. 이후 승인된 31종 PNG와 해당 manifest 표시/출처 정보만 반영했다. SpriteFrames·전투 코드 변경과 Android 기기 확인은 없다.
- 2026-10-15 사용자 “승인한다.”로 새 idle·run·attack_air_heavy 3종을 승인했다. `approval-proof-3.json`에 시트·GIF·미리보기·참조와 원본의 해시를 고정했다. 미제작 모션까지 승인된 것으로 처리하지 않는다.
- 현재 단계: 새 28종을 승인받았다. `approval-all-31.json`은 보여 준 28종과 이전 승인 3종의 파일 해시를 고정한다. `31-motion-report.json`과 `pending-review-28.json`은 승인 전 상태의 원본 기록으로 보존하며, 현재 승인 상태는 새 승인 파일을 따른다.
- `install_approved_myo.py`로 승인 셀 픽셀을 크기 변경 없이 2048×128로 옮겼다. 기존 31종 PNG·manifest 백업은 `07_before_install/`, 결과는 `08_install_receipt.json`이다. 표시 배율 1.0, 발 기준 124 외 ID/FPS/반복·SpriteFrames·전투 데이터는 유지했다.
- `install_approved_myo.py --check`로 496셀 픽셀 일치와 다른 89종/콘셉트/전투 데이터 보존을 확인했다. 나비는 별도 `07_nabi-style-locked/`에서 제작하며 승인 전 런타임에 반영하지 않는다.
- 승인 전 시안 단계로 남겼으므로 commit/push/PR/병합은 수행하지 않았다. 기존 미커밋 변경은 보존했다.
