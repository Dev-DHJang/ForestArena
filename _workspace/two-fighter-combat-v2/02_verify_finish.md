# 전체 검사 정리

## 범위

- 기존 제품 검사에서 활성 자현·나비와 장신구 미장착 정책으로 달라진 기대값을 확인한다. 전체 보유4캐릭터·6장신구 ID를 보존하는 저장 검사는 유지한다.
- 새 전투·신규 모션 승인·실제 Android 기기를 같은 완료 상태로 기록하지 않는다. 원본 사용자 폴더는 수정하지 않는다.

## 검사 보완

- 모션 후보 타임라인의 나비 특수 회복 기대값을 승인 수치20tick으로 맞췄다. 기존 기대24는 이전 구현값이었다.
- `tests/premium_menu_runtime.gd`의 출력 경로를 이번 작업의 `qa/premium-menu-runtime/`으로 옮겼다. 이전 실행이 덮었던 과거 `runtime-report.json`은 이번 작업 `qa/premium-menu-runtime-before-redirection.json`에 보존하고 과거 파일은 HEAD 내용으로 복원했다.

- `tests/android_qa_session.gd`의 구매·선택·재실행 기대값을 두 캐릭터·미장착에 맞췄다. 비활성 상품 구매는 거부되고 보유 기록이 바뀌지 않는지, QA 자동 명령으로도 비활성 캐릭터와 장신구를 선택할 수 없는지 추가 확인한다. 명령 중복 거부·나쁜 모드 거부·실제 경기 관찰·중단/복귀·터치 진단·재시작 저장 확인은 유지했다.

## 실행 결과

- 전체 첫 실행은 Python 모션 후보 테스트 기대24와 실제20 불일치로 중단했다. 로그: `qa/verify-finish-full.log`.
- 회복 기대값 수정 뒤 `qa/verify-finish-full-r02.log`는 Android QA 세션 검사까지 진행했고 구제품 장신구 기대값에서 중단했다. 앞의 신규 전투·제품·AI와 기존16대진+전체 재현1회·모든 메뉴/기반 검사들은 PASS다. 별도 Godot 중간 실행은 전체 재실행과 중복되어 중단했으며 통과 완료로 계산하지 않는다(`qa/verify-finish-godot-tail.log`).
- `./scripts/verify-docs.sh`: PASS (`qa/verify-finish-docs.log`).
- `python3 tools/forest_arena/verify_godot_resources.py --project-root .`: PASS,519개 논리 자산·25개 품질 차이(`qa/verify-finish-resources.log`).

- `tests/android_qa_session.gd` 보완 뒤 개별 검사 PASS (`qa/verify-finish-android-qa-session.log`).
- 나머지 전체 스크립트 구간은 PASS (`qa/verify-finish-remaining.log`): 메뉴 공통 callback, LAN 결과 저장·계약·재접속, 실제 loopback 서버와 두 클라이언트의 연결/결과/재대전, QA 두 경기 분리, API TypeScript 검사, 온라인 계약과 하네스. 이 LAN 결과는 테스트 인증 서버를 쓴 로컬 연결 확인이며 PostgreSQL이나 물리 Android 통과를 뜻하지 않는다.
- `./scripts/verify.sh` 전체 단일 실행은 `qa/verify-finish-full-r03.log`의 `Forest Arena verification passed.`까지 완료했다. 그 뒤 시각 QA에서 발견한 하강·다운·기상 표시 구간을 보완했고, 최종 r04도 완료했고 `qa/verify-final-r04.log`에 기록했다.
- 프리미엄 메뉴는2841개 검사·81상태 모두 PASS, 실패0(`qa/premium-menu-runtime/runtime-report.json`). native_capture=false, device_test=not_run이다.

## 남은 확인과 경고

- 현재까지 SCRIPT ERROR와 실제 동작 실패를 exit0으로 무시한 항목은 없다. 기존 검사 종료 때 ObjectDB/Resource 정리 경고는 별도 집계하며 기능 통과와 구분한다.
- Godot 편집기 실행 때 Android adb daemon 연결 거부 문구가 있었다. 이는 연결된 Android 기기 검사를 하지 않았음을 뜻하며, 이 실행으로 실기기 통과를 주장하지 않는다.
- 새 모션의 독립 시각 검토·모션별 사용자 승인·실제 Android 검사는 이 담당의 확인 범위 밖이다.
