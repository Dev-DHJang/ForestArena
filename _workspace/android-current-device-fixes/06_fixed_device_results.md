# 수정 APK 실기기 결과

APK는 `a42857320d1a41a5e707a457d6ce71f03aba9b0e38241e4d693b04fe1f850e48`이다. source HEAD 9de51fbff130417c207ef4ef3d1e7c4e7c8d0fbf, 도구와 APK 모두 같은 수정 작업 사본을 사용한다. 원본 APK의 결과와 섞지 않는다. source-before-export-r02.json 2101개 런타임 파일 hash 및 실제 APK 권한/내용을 독립 QA가 다시 확인했다.

사용자 갱신 지시는 S23 주 검사, Tab S5e LAN 상대다. S23 hardware R3CW201479A(Android16/SDK36), Tab R54R404CZYJ(Android11/SDK30)이며 mDNS 새 주소 연결 뒤 serial을 확인했다. 기기 주소가 바뀌어도 별칭·하드웨어 식별과 APK hash로 비교한다.

| 사례 | S23 새 APK 증거 | 현재 판정 |
| --- | --- | --- |
| DEV-01 | b49 설치·가로·콜드 시작; d600 새 준비 검사122.403초 pass | pass |
| UI-01 | b49 실제 첫 선택·무료 구매·설정·재실행 복원; d60037.866초 pass | pass |
| OFF-01 | b49 네 캐릭터·없음/6장신구 실제 경기 데이터 | pass(선택 반영 범위) |
| INPUT-01 | b49 실제 ADB press/release·행동·조건 전후 궁극기 | pass(자동 ADB 범위) |
| LIFE-01 | b49 BACK/HOME/새 foreground 진단·계속/준비/로비 | pass |
| OFF-02 | b49 정상 전투 결과·재대전 체력/기회/입력 초기화 | pass |
| MODE-01 | b49 연습/Story 진입·복귀와 Solo8/Team4대4 실제 결과 | pass |
| SOAK-01 | d600 600초 설정·608.196초 관측·9판 결과/재대전·9조합 | pass |
| LAN-01/02/03 | 03b5e3f0513048ed8dd6738433bcb885 두 APK 별도 새 시도 | 실행 중 |
| MANUAL-01 및 사용자 수정 재확인 | 새 APK 실제 Wi-Fi·방향+회피/공격·모션·경직·콤보·소리/진동 | 미실행 |

최초 b49 실행은 원시 집계13pass2fail8blocked2미실행을 보존한다. 사용자가 검사 도중 직접 조작했다고 확인했으며 S23 SOAK 실패는 pause 캡처, Tab MODE 실패는 pause/foreground 손실/최근앱 캡처다. 직접 조작이 섞인 시도라고 구분하며 모든 실패의 원인을 확정하거나 원본 fail을 pass로 덮어쓰지 않는다. 정확한 조작 시점은 미확인이다.

S23 새 반복 시도 d600은 독립 SOAK 범위의3pass9미실행이다. full_suite_executed false이며 이 시도 하나를 전체 기능 통과라고 해석하지 않는다. 9개 완료 조합은 자현 없음/6종 모두와 묘령 없음/권투장갑이다. 진행 중이던 다음 조합은 완료로 세지 않는다. 28조합 전체·30분 extended·네 실제 기기 실행을 통과로 주장하지 않는다.

S23 일반 저장은 b49와 d600에서 before{}/after{} unchanged true다. 기존 비어 있지 않은 프로필 복원 검사로 확대하지 않는다. Tab b49 정리 시 after는 못 읽어 blocked이며 재연결 후 별도 original-stores-after-reconnect.json에서 {}→{} 동일을 확인했다. 원래 정리 시점의 미확인은 유지한다.

## S23 반복 검사 성능과 로그

`d600.../device-1/performance-summary-reviewed.json`은 raw126샘플 중 generation+msec 중복을 제외한108개 새 샘플을 정리한다. FPS56.908~60.103, 중앙값60.000. 각300프레임 구간p95는16.666~16.667ms이며 전체600초의 단일p95라고 해석하지 않는다. 시스템23샘플의 PSS392.288~488.574MiB, 조회 가능한 양수 온도 센서32.0~51.2℃, thermal status0이다. 센서 종류별 값과 준비/재실행/정리 구간을 포함하므로 배터리/표면 온도 또는 반복 전투만의 평균으로 확대하지 않는다. 승인된 성능 합격 수치는 없으며 측정값만 보고한다.

앱 UID 로그는 검사 종료까지 살아 있고 cleanup 종료-15는 도구가 수집 process를 끝낸 값이다. 게임 충돌 exit코드로 해석하지 않는다. 자동 입력 끄기는 confirmed_disabled, offline-cleanup은 home/autoplay false/lan_eligible true다. 게임/서버 로그에서 토큰과 비밀값은 제거하고 APK·JSON·주요 PNG는 별도 build 증거에 보존한다.

원본 작업 폴더 기준2913파일의 재해시 차이0을 `original-preservation-r02.json`에서 확인했다. 전체 코드 검사·APK 검사와 실제 사용자 관측은 다른 증거이며, 사람이 새 APK를 확인하기 전에는 이전 사용자 실패를 해결 완료로 기록하지 않는다.
