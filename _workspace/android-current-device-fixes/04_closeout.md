# 실기기 발견 문제 수정 마무리 상태

현재 승인 범위의 제품 검사는 완료됐다. 새 APK의 S23 기능·10분9판,두 APK LAN·앱 단절,실제 Wi-Fi 복귀와 S23 자현 사용자7항목 정상 재확인을 마쳤다. 독립QA가 통과 판정했고 원격 통합과 병합/rollback 기록을 마무리 중이다. 원래 작업 폴더의 미커밋 코드와 승인 캐릭터 PNG·SpriteFrames·manifest는 보존했다. 이전 APK와 실패·차단 증거도 별도로 유지한다.

## 코드와 통합 검사

최신 origin/develop cf081dd334ef619450d612844f6206f560ea2cc0에서 별도 작업 사본 `/Users/jdh/.codex/worktrees/android-current-fixes/ForestArena`와 `codex/android-current-device-fixes`를 만들었다. HEAD 9de51fbff130417c207ef4ef3d1e7c4e7c8d0fbf는 원격에 push했고 PR #90은 draft다. 자동 검사 도구 PR #89의 f7061f5 코드를 합쳤다. 아직 develop 병합은 하지 않았다.

- 전투: 방향 입력 중 일반 공격의 불필요한 이동, 피격 중 행동, 접지 피격 미끄러짐, 콤보 시작·방향과 종료 상태를 수정했다. 네 캐릭터 실제 적중 콤보는 자현 3단/15, 묘령 4단/19, 나비 2단/11, 유란 3단/15다.
- 표현: 승인 120모션의 해시가 맞을 때만 모션별 고정 몸 배율과 발 기준을 적용한다. 원본 그림·SpriteFrames·manifest 변경은 0이다. 실제 renderer 0/8/15 프레임 비교와 QA를 마쳤고 전체 프레임의 사람 검사로 확대하지 않는다.
- UI: 승인 숲빛 v06 자산을 논리 ID로 현재 메뉴·선택·상점·설정·LAN·결과·전투 HUD·고정 조이스틱에 연결했다. 다인전 카드의 같은 인원 수 ID 변경과 제거 직전 viewport callback 문제도 QA 지적 뒤 고쳤다.
- 오디오/진동: 기존 승인 음악·효과음을 포함하며 QA 오디오 설정 저장을 분리하고 Android VIBRATE 권한을 추가했다. 실제 청취·진동은 사용자 재검사 전까지 미확인이다.
- LAN: 인증된 기존 참가자의 유효 토큰으로 새 연결이 기존 socket 종료를 기다릴 때 resume_pending 재시도, 입력 해제, 기존 60초 기한 불연장을 검사했다. 이전 실제 Wi-Fi 실패 원인 전체가 확정됐다고 주장하지 않는다.

`build/android-current-fixes/verify-integrated-r02.log`는 전체 verify.sh 종료 코드 0, “Forest Arena verification passed.”, host 118개, SCRIPT ERROR 0이다. Android native touch·실행 인자, 모드·전투·오디오, LAN/API/서버 분리·문서·하네스·리소스를 포함한다. 리소스는 논리 ID 491개·품질 변형 24개다. 일부 기존 종료 정리 경고는 로그에 보존한다. 최초 통합 r01의 중복 signal 실패와 종료 코드 143은 삭제하지 않았다.

## 실제 생성 APK

`build/android-current-fixes/ForestArena-current-fixed-r01.apk` SHA-256은 `a42857320d1a41a5e707a457d6ce71f03aba9b0e38241e4d693b04fe1f850e48`이다. package com.forestarena.welllbeing, source HEAD 9de51fb, Godot 4.7.1. source-before-export-r02.json의 2101개 파일은 export 전후 변경 0이다. apk-fixed-r01.json과 export-r02.log에서 실제 export 종료 0, Android 패키지 검사 통과, INTERNET/VIBRATE 권한과 리소스·오디오·표시 JSON 포함을 확인했다.

새 Android template 설치가 독립 옵션만으로 앱을 실행하던 exporter를 지원되는 export-debug와 함께 실행하도록 고쳤다. 최초 export-r01 중단 로그와 owned process 종료 143은 유지한다. 새 export-r02는 실제 fresh template 생성과 native QA adapter 준비 뒤 최종 APK export를 완료했다.

## 실기기 재검사

첫 새 APK 실행 `b49ce3fd6dfc40528deeeae426611207`의 원본 집계는 13 pass / 2 fail / 8 blocked / 2 미실행이다. S23은 DEV/UI/OFF-01/INPUT/LIFE/OFF-02/MODE 통과했고, 연습·Solo 8명·Team 4대4 실제 결과·Story 프롤로그 진입과 복귀를 확인했다. SOAK은 약 201.8초·완료 조합 3개 뒤 일시정지 화면으로 바뀌어 실패했다. Tab은 기능 6개 pass, MODE 실패와 저장 종료 확인 blocked다. LAN은 실행되지 않았다.

사용자가 검사 도중 직접 조작했음을 확인했다. S23에 자동 대전 중 실제 touch 이벤트가 추가되고 Tab foreground 손실/일시정지가 기록됐다. 조작이 섞인 시도임을 기록하지만 원본 fail을 pass로 수정하지 않는다. S23 기존 일반 저장 전후는 {}→{}, unchanged true이며 Tab의 after는 읽지 못해 미확인이다.

사용자의 갱신 지시에 따라 S23만 오프라인 주 검사 기기로 삼고 Tab은 LAN 상대에만 사용한다. 새 무선 주소는 mDNS 발견과 hardware serial 확인 뒤 연결했다. S23 10분 반복 재검사 `d6002041832f4ba6a2f37babd9907609`는 종료 0, SOAK-01 pass(608.196초, 설정 600초), 정상 결과·재대전 9판/9조합이다. 로비 복귀·자동 입력 해제·일반 저장 {}→{}도 확인했다. 별도 LAN 검사 `03b5e3f0513048ed8dd6738433bcb885`는 정상 경기·재대전·HOME·10초/65초 앱 단절을 통과했다. LAN-02 원시 blocked는 보존하고 쌍별 네 오류 PNG를 직접 읽어 별도 시각 확인 pass로 남겼다. 이전 관측이 끊긴 실행은 results.json과 살아 있는 process를 확인하고 종료된 사실을 확인했다.

## 원격 통합과 남은 확인

PR #89: https://github.com/Dev-DHJang/ForestArena/pull/89
PR #90: https://github.com/Dev-DHJang/ForestArena/pull/90

새 APK의 LAN 자동 검사는 완료했고 실제 Wi-Fi 재접속은 새 수동 경기에서 같은 슬롯 복귀와 사용자의 이동/공격 가능 응답을 확인했다. 정확한 OFF 초 수·Tab 문구 체감은 미확인이다. S23 자현의 방향+공격/회피·모션·경직·콤보·BGM·효과음·진동은 사용자 정상 답변과 실제 화면/저장/로그를 확인했다. 성능에는 승인된 합격 수치가 없어서 측정값만 보고한다. 독립 QA의 코드 검사와 전체/APK/실기기 증거 감사는 구분한다.

develop 통합은 QA와 실제 재검사 뒤 진행하며 병합 SHA와 실제 rollback 명령을 추가한다. main 승격·release 분기·강제 push·원격 브랜치 삭제는 하지 않는다. 되돌릴 때 이 작업의 통합 커밋을 revert하고 APK·실패·사용자 응답 증거는 보존한다.

빌드 당시2101파일을 frozen-apk-source-r01 사본으로 보존해 SHA변경0을 확인했다. 이후 명령 진단의device/step/expected/observed와 실제 응답 기록 보완은 도구만 바꾸며 게임APK a428…는 그대로다. 변경된 host120개와 실제 같은 APK S23context명령 호환성 확인을 추가했다. 최종12사례/사용자7항목의 결과와 정확한 한계는 06_fixed_device_results.md/final-device-composite.json에 있다.
