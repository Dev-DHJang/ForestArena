# 타이틀·화면 로딩·머리 비율 작업 마무리

2026-10-16 상태: **타이틀·화면 전환 구현과 데스크톱 검사 완료, 캐릭터 표본 승인 대기**.
전체90모션 재제작·게임 반영 완료는 아니다.

## 반영한 동작

- 전용 캐릭터 없는 숲 타이틀, 실제 하단 시작 준비 진행률, 완료 뒤 새 터치로1회 진입.
- 기본 v0.0.1·Demo v0.1.0-demo와 © 2026 Forest Arena. All rights reserved. 표시.
- 화면 이동150ms 뒤에만 중앙 로딩바, 중복 입력·늦은 결과 차단, 실패 재시도·이전 화면.
- 선택 참가자의 모션 준비 전 경기 시간·입력 정지, DB·LAN 자동 완료 알림 보존.
- Android 검사 도구도 타이틀 준비를 기다린 뒤 실제 터치로 진입한다.
- 타이틀 원본·품질3종·설계 전달 이미지를 새로 등록했다. 내장 image_gen 제작이며 정확한
  프롬프트·출처·SHA-256은 `assets/ui/title-v01/manifest.json`이다. 기존 승인 이미지는 보존했다.

## 캐릭터 비율

- 최신 묘령 대기 표본을 재사용하고 나비·유란의 머리 가로폭을 내장 이미지 도구로 보정했다.
- 자현27px, 묘령28px, 나비약28.27px, 유란약26.53px의 첫 자세 수동 측정 결과다.
  귀·늘어진 머리카락을 제외한 측정이며 전체 관절·전프레임10% 통과를 주장하지 않는다.
- `character-review/comparison-before-after.png`, 각16포즈 시트·GIF·측정선과 해시를 제공한다.
- 대상90종과 자현30종의 기존 PNG·SpriteFrames·manifest·외형 계약은 그대로다.
- 세 대기 표본의 새 승인을 요청했다. 승인 뒤 묘령→나비→유란 순으로 전체 모션 검토와
  모션별 승인·게임 등록을 진행한다. 새 기준 후보가 없는 나비28·유란29종은 아직 제작 전이다.
- 근거: `.agents/skills/forest-arena-2d-animation/SKILL.md`의 “모션별 사용자 명시 승인 전에는
  런타임 경로·manifest에 쓰지 않고” 규칙. 구현 지시를 개별 이미지 승인으로 바꾸지 않았다.

## 검사

- `./scripts/verify.sh`: 종료0, `Forest Arena verification passed.` (`verify-full.log`).
  전체 대전·메뉴·저장·LAN·서버 계약 검사를 포함한다. 기존 전투 검사들의 종료 정리 과정에
  ObjectDB·리소스 경고가 남아 있으며 무경고라고 보고하지 않는다.
- `tests/title_loading_flow.gd`:73항목 통과 (`ui-title-loading-flow.log`, 전체 검사에서도73통과).
- Android fleet 호스트 단위 검사126항목 통과 (`ui-android-fleet-tests.log`).
- 독립 실제 macOS 렌더34항목과 별도 자동70항목 통과.
  16:9·20:9 최종 가독성과 중앙 진행바는 `03_qa_r02.md`, `qa-captures/` 참고.
- 문서·하네스·Godot 리소스 검사 통과. 논리 자산519개, 품질 변형25개.
- 비율 시안 구조·기존 파일 보존 검사 통과 (`verify-character-review.log`).
- Android debug APK 생성·패키지 검사 통과. 첫 패키지 검사에서 Godot 설정 파일 파서를
  수정한 뒤 재검사했다. 최종 APK와 해시는 아래에 기록한다.
- Android 실제 기기: 연결된 기기가 없어 미실행. 터치·중단/복귀·실제 메모리는 미확인이다.

## Git·되돌리기

- 기준: origin/develop `57c7143372e4c0ef20a2aed291755523ceb7bd77`.
- 작업 브랜치: `codex/title-loading-proportions`.
- 원래 ForestTales/ForestArena 작업 폴더의 미커밋 변경을 보존하고 별도 관리 작업 폴더에서 구현했다.
- PR·최종 병합 정보는 원격 작업 완료 뒤 덧붙인다.
- 되돌리기는 해당 PR 병합 변경을 되돌리는 새 커밋으로 한다. 기존 사용자 작업은 복원 대상으로 삼지 않는다.

## 최종 Android 산출물

- APK: `build/android/ForestArena-debug.apk`. 설치·실제 기기 검사는 미실행.
- SHA-256: `56e23514d2775539af7de53b4510b507082b0f00399c96563f05f6ec25c68be3`.
- 최종 생성·패키지 검사 종료0: `export-android-final.log`.
