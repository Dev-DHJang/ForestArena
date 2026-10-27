# 최종 검사 절차 수정 독립 검토 r05

2026-10-28. 담당 `final_scope_review`. 판정: **PASS — 검사 생략·완화가 아닌 승인본 기준과 실행 순서의 수정이다.** 대상은 `scripts/verify.sh`와 `tests/character_motion_contract.gd`의 이번 변경뿐이다. 제품 코드·원화·등록 파일은 변경하지 않았다.

나비 점프의 이전 manifest는12 FPS였다. 승인된 최종 카탈로그·후보 TRES·등록 manifest·등록 TRES는 모두8 FPS이다. “기존8 FPS 유지”라는 제작 전달은 잘못됐고, `02_integration_notes.md`에서 이 점을 명시적으로 정정했다. 검사 상수는 나비 jump 한 항목만12→8로 바뀌며 다른 캐릭터·모션의 기준, 비반복 조건, manifest/TRES FPS 동등성 검사와 전체 프레임/alpha/해시/소비 경로 검사는 그대로다. 승인된 파일을 검사에 맞추려고 바꾼 것이 아니라 실제 승인본을 정확히 검사하도록 기준을 갱신한 것이다.

검사 스크립트는 기존의 Godot 자산 가져오기 명령 한 번을 Python의 Godot 재생 검사 앞으로 이동한다. 변경 전후 주석을 제외한 명령을 직접 비교해 이 이동 외의 기존 명령·순서가 같고, 가져오기는 한 번만 있으며 `set -eu`도 유지됨을 확인했다. 새 PNG를 가져오기 전에 Texture2D를 불러오는 실패를 통과 처리하거나 검사 자체를 끄지 않는다.

승인 검증 함수와 계획·설치 후 출력 SHA를 다시 읽기 전용으로 대조해 승인 카탈로그/PNG/TRES/manifest가 승인 계획과 여전히 일치함을 확인했다. `fighter_controller.gd`, `local_fighter_presentation.gd`와 나비 전투 데이터는 develop 기준과 바이트가 같아60Hz 전투·점프 물리·표시 상태 처리의 변경은 없다. 독립 검토에서는 전체 검사를 중복 실행하지 않았으며 최종 r05 실행 결과는 조율 담당이 확정한다. 실패 이력 r03/r04는 보존한다.

파일 SHA와 명령/출력 대조 결과는 `qa/verification-review-proof-r05.json`이다. 이번 검토는 실제 Android 통과를 포함하지 않는다.
