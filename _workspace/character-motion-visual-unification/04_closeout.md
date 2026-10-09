# 캐릭터 모션 외형 통일 작업 기록

상태: 승인본 로컬 등록·자동 검증 완료. 물리 Android 재생·성능은 미확인.

## 2026-10-09 재개와 원격 통합

- 사용자 지시로 Android 검증을 이후로 미뤘다. 이번 재개에서 Android export·기기 연결·설치·실행을 새로 검사하지 않았다.
- 현재 작업트리 전체 검사 재실행 통과: `completion-verify-2026-10-09.log`.
- 감사가 누락·중복·오류에도 성공 종료하던 문제를 수정했다. 정상·누락·로스터·중복·해시·alpha·빈 프레임·오래된 경로의 단위 검사 10개 통과.
- 등록 목록 밖에 남은 나비 과거 약공격 파일 2개를 같은 승인 시트로 맞췄다. 새로운 포즈나 ID는 없고 이전 파일은 백업했다(`08_legacy_aliases.json`). 이제 고유 120종과 물리 122개를 함께 검사한다.
- 팀 명세와 기존 승인 계획의 원격 통합 조건이 남아 있어 Goal을 완료하지 않았다. 별도 관리 작업 공간 `/Users/jdh/.codex/worktrees/motion-unification/ForestTales`, 최신 develop af41ac0, 브랜치 `feature/motion-visual-unification`에 관련 변경만 복사했다.
- 통합 공간 전체 검사도 exit 0으로 통과했다. QA 1회차 fix와 2회차 자동·교차 검증 결과는 `03_qa_r01.md`, `03_qa_r02.md`에 있다.
- 구현 커밋: `6e1f0db5d99c5379e44ab22662f4b93e08619151`. PR·원격 검토·병합은 현재 진행 중이다. 기존 PR #59는 이미 병합됐으므로 수정하지 않았다.
- 원래 작업트리의 다른 미커밋 변경을 수정·커밋하지 않았다. `main` 승격, 강제 push, 원격 브랜치 삭제는 수행하지 않는다.
- PR: https://github.com/Dev-DHJang/ForestArena/pull/76. 원격 Codex 검토를 요청했고 검토 실행을 확인했다. 완료 결과를 확인하기 전에는 통과로 기록하지 않는다.
- 추가된 최신 develop `ec08dd8dbff349fb07f93694d5289a6627eddb50`을 충돌 없이 정상 병합했다. 통합 커밋 `6ca7960519d5e445e2866a80ff036523a9c2c1a9`을 push했고 전체 검사를 재실행 중이다.
- 메타데이터 백업 이동 추가 승인 뒤 `05_before_install/docs.DS_Store`가 보존되고 원래 `docs/.DS_Store`가 없음을 확인했다. 문서 검사 재실행 통과. 이미 이동한 파일을 다시 삭제하거나 덮어쓰지 않았다.

아래 2026-10-08 내용은 당시 결과다. 현재 Android 검증은 명시 이연됐으며, 원격 통합 완료 여부는 위 재개 기록을 따른다.

## 최종 결과 — 2026-10-08 승인 반영

- 사용자가 `03_review.md`의 119종 교체 후보를 명시 승인했다. 승인 목록 SHA-256과 메시지는 `approval.json`에 기록했다.
- 자현 29종·묘령 31종·나비 29종·유란 30종 PNG를 기존 런타임 경로에 등록하고 manifest의 해시·출처·사용자 승인 기록을 갱신했다. 자현 `attack_heavy_charge`는 파일·manifest 항목 모두 그대로 유지했다.
- SpriteFrames 파일·경로, 기존 시각 상태 ID, FPS·반복·공격 수치는 유지했다. 기본 모션에 누락됐던 동일 이름의 `visual_state_id`와 공통 발 기준점 `foot_pivot_y: 124`를 연결했다.
- `05_before_install/`에 이전 dirty 런타임 PNG와 manifest를 복사했다. `05_install_receipt.json`에 전후 해시와 유지한 SpriteFrames·기준 시트 해시를 기록했다. 관련 없는 manifest 항목이 이전 상태와 같은지도 검사했다.
- 사용자 추가 승인에 따라 `docs/.DS_Store`를 `05_before_install/docs.DS_Store`로 옮겼다. 삭제하지 않았으므로 원위치로 복원할 수 있다. 다른 작업의 미커밋 변경은 유지했다.
- `./scripts/verify.sh` 전체 통과(`installed-verify.log`). 캐릭터 모션·공격 모션·점프 표시 검사, 문서·하네스, LAN·온라인 서버 검사 포함. 이후 추가한 기본/점프 발 기준점 검사는 개별 재실행에서도 통과했다.
- `install_motion_unification.py --check`, `test_motion_visual_tools.py` 5개 검사, Godot 리소스 346개, `git diff --check` 통과.
- 실제 Godot Compatibility 렌더러에서 네 캐릭터의 정지·좌향 달리기·점프 상승/하강을 표시해 `installed-presentation.png`와 `installed-presentation-zoom-05.png`를 저장하고 확인했다. 머리·귀·꼬리의 큰 형태와 좌우 반전은 읽히며, 축소 시 작은 얼굴·장식 세부가 줄어드는 점은 남는다.
- 데스크톱 합성 표본(16개 표시 인스턴스)의 텍스처 메모리는 201,049,280 bytes, draw call은 116이었다(`installed-presentation.log`). 실제 Android 경기 성능이나 변경 전 대비 GPU 증감으로 해석하지 않는다.
- 교체 PNG 합계: 이전 33,936,259 bytes → 이후 22,214,188 bytes. 119종 2048×128 RGBA8 원시 픽셀량은 124,780,544 bytes로 해상도 예산은 유지했다. mipmap·드라이버 메모리는 별도다.
- 최종 Android debug export와 APK 패키지 계약 통과(`installed-android-export.log`). 파일: `build/android/ForestArena-debug.apk`, SHA-256 `2e1aa0652f1ed5b0a787e0038e061bf41df1c669244bf4fa77bd87bcc694c3b2`.
- `adb devices -l`에서 연결 기기 없음. 에뮬레이터·물리 Android 실행이나 실제 Android GPU 메모리 검증은 통과로 기록하지 않았다.
- 이 턴에서는 커밋·PR·원격 병합을 수행하지 않았다. 기존 Goal 상태는 자동 변경하지 않았다.

아래 내용은 중간 진행 이력이며, 현재 상태는 위 최종 결과를 따른다.

## 최신 재개 결과 — 후보 승인 대기

- 기존 완료 조건과 승인 경계를 유지했다. Goal을 새로 만들거나 완료로 바꾸지 않았다.
- 120종 전체 개요판을 확인했고 자현 기준 `attack_heavy_charge`는 그대로 유지한다.
- 검토 후보 119종: 자현 29, 묘령 31, 나비 29, 유란 30. 정확한 목록은 `03_review.md`, 해시와 출처는 `03_staged/report.json`이다.
- 내장 이미지 생성 도구로 실패 모션을 다시 생성했다. 자현 중립 특수기 r05, 묘령 아래 특수기 r06을 선택했고, 그 이전 잘림·중복 후보는 승인 대상에서 제외했다.
- 밝은 회색 배경을 쓰는 묘령 5종은 별도 배경 판별로 복원했다. 새 생성본의 여백 차이는 모션 단위 고정 배율로 조정했으며 프레임별 임의 확대는 하지 않았다.
- `verify_staged_motion_unification.py` 통과: 119종, 1904프레임, RGBA, 2048×128, 16개 비어 있지 않은 셀, 실제 투명도, 원본/결과 SHA-256. 이 검사는 디자인 일치나 사용자 승인을 뜻하지 않는다.
- `test_motion_visual_tools.py` 5개 단위 검사, `local_fighter_presentation.gd`의 네 캐릭터 점프 재생 검사, 문서·하네스 검사, Godot 리소스 346개 검사 통과.
- 전체 검사 첫 재실행은 제한된 환경에서 Godot 비정상 종료. 허용된 확장 실행은 `verify.sh`가 실행 중 변경되는 시점에 `ess: command not found`로 중단됐다. 다른 작업의 스크립트를 수정하지 않고 고정 복사본으로 재검증 중이다.
- 최신 Android debug export와 APK 패키지 계약 검사는 통과했다(`resume-android-export.log`). 이 APK는 점프 재생 수정을 포함하지만 승인 전 119종 후보 이미지는 포함하지 않는다. 물리 기기 실행 결과는 아니다.
- 이후 최신 문서 검사 재실행은 `docs/.DS_Store` 때문에 실패했다. 앞선 문서·하네스 통과는 그 시점의 결과다. 작업 범위 밖의 파일과 동시 변경 중인 `docs/INDEX.md`, `scripts/verify.sh`, 세션 복구 도구는 수정하지 않았다. 전체 검사 최종 통과는 아직 주장하지 않는다.
- 고정 복사본 전체 검사도 완료됐으며 게임·LAN·온라인 서버·Godot 리소스 검사를 통과한 뒤 동일한 문서 검사 문제로 exit 1이 됐다(`resume-verify-snapshot.log`). 검사 통과를 위해 해당 파일을 삭제하거나 검사를 완화하지 않았다.
- 검토 전용 폴더에 `.gdignore`를 두어 후보가 Godot 게임 리소스로 자동 import되지 않도록 했다.
- 런타임 PNG·manifest·SpriteFrames는 이 작업에서 교체하지 않았다. 기존 나비·유란 변경 및 다른 작업의 변경은 보존했다.
- 다음 단계: `03_review.md`의 후보 119종에 대한 사용자 명시 승인 → 승인본만 등록 → 게임 내 크기·연결 동작 재검사와 최종 전체 검사/Android export. 실제 물리 Android 기기 통과는 아직 없다.

## 2026-10-08 재개 지점

- Goal 조회 결과는 `usageLimited`다. 완료나 사용자 요청에 의한 일시 정지로 바꾸지 않았다.
- `./scripts/verify.sh` 전체 검사 통과. Godot 리소스 346개, 문서·하네스 검사 포함.
- `./scripts/export-debug-android.sh`는 제한된 실행에서 실패했으나 허용된 확장 실행에서 APK 생성과 패키지 계약 검사 통과. 기록: `android-export.log`.
- 실제 물리 Android 기기는 실행하지 않았다.
- `python3 tools/forest_arena/test_motion_visual_tools.py` 4개 검사 통과: 칸을 넘는 팔 보존, 포즈 누락 거부, 검은 옷 보존, 분리된 조각 표시.
- 새 이미지는 검토용 경로에만 있다. 이 작업에서 런타임 PNG·manifest·SpriteFrames를 교체하지 않았다. 이전 작업의 나비·유란 변경은 유지했다.
- 복원 소스 106개를 `02_drafts/*/*-r00.png`로 준비했다. 이것은 검수 통과나 교체 승인을 뜻하지 않는다.
- 자현 6종, 묘령 7종과 나비 대시 강공격·유란 옆/위 강공격·등장 시안을 재생성했다. 생성 일부는 분리 검사에서 다시 확인해야 한다.
- `03_staged/report.json`은 분리 성공분의 임시 결과이고, `03_staged/failures.json`은 미해결 목록이다. 승인 요청용 최종 목록이 아니다.
- 변환 문제의 추가 원인: 기존 회색 배경 제거가 검은 의상을 지웠고, 고정 4×4 칸 자르기가 귀·신체를 잘랐다. `recover_motion_review_sources.py`와 `motion_sheet_regions.py`로 복원 방법을 검사 중이다.
- 다음 작업: 마지막 시트 분리 결과 확인 → 배경 종류별 복원 개선 → 연결된 포즈·원본 잘림 개별 재생성 → 120종별 수동 판정 확정 → 최종 후보 시트/GIF/해시 승인 요청 → 승인 후에만 런타임 등록과 최종 검사.
- `motion_sheet_regions.py`는 alpha 32 이상을 포즈 분리 기준으로 사용하도록 마지막 수정했다. 이 수정 뒤 단위 검사를 다시 실행해야 한다. 원본 가장자리 접촉은 잘림과 같지 않으므로 수동 판정이 필요하다.

## 현재 단계

- 등록된 네 캐릭터의 전체 런타임 시트 및 16프레임 전수 감사.
- 자현의 콘셉트·기준 시트 대비 외형 편차와 비정상 동작 분류.
- 다른 캐릭터의 규격·잘림·외형·동작 이상 분류.

## 확인된 진행 결과

- 120개 등록 시트의 원본 규격·alpha·16셀·manifest 해시 검사 통과.
- 점프 재생을 실제 상승·정점·하강과 착지 상태에 맞춰 수정.
- `tests/local_fighter_presentation.gd`에 네 캐릭터 점프 단계·공중 재점프·플랫폼 낙하·착지 중단 검사를 추가했고 통과.
- 자현 6종 검토 원본은 있으나 칸 경계 이상이 발견되어 아직 런타임 교체 후보로 통과하지 않았다.
- 런타임 이미지 교체와 모션 승인 요청은 아직 수행하지 않았다.

## 완료 전 남은 항목

- 전수 감사 결과 확정.
- 필요한 교체 시안 제작과 사용자 승인.
- 승인본 런타임 등록 및 manifest 갱신.
- 전체 검사와 Android debug export.
