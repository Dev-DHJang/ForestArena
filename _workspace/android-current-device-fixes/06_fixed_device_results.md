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
| LAN-01/03 | 03b5e3f0513048ed8dd6738433bcb885 두 APK 정상 결과·재대전·10/65초 앱 단절 | pass |
| LAN-02 | 같은 실행 실제 네 오류 PNG를 root가 읽고 별도 lan02-visual-review.json 저장 | 쌍별 시각 확인 pass; raw blocked 보존 |
| MANUAL-01 및 사용자 수정 재확인 | 새 APK 실제 Wi-Fi·방향+회피/공격·모션·경직·콤보·소리/진동 | pass(S23 자현 직접 확인) |

최초 b49 실행은 원시 집계13pass2fail8blocked2미실행을 보존한다. 사용자가 검사 도중 직접 조작했다고 확인했으며 S23 SOAK 실패는 pause 캡처, Tab MODE 실패는 pause/foreground 손실/최근앱 캡처다. 직접 조작이 섞인 시도라고 구분하며 모든 실패의 원인을 확정하거나 원본 fail을 pass로 덮어쓰지 않는다. 정확한 조작 시점은 미확인이다.

S23 새 반복 시도 d600은 독립 SOAK 범위의3pass9미실행이다. full_suite_executed false이며 이 시도 하나를 전체 기능 통과라고 해석하지 않는다. 9개 완료 조합은 자현 없음/6종 모두와 묘령 없음/권투장갑이다. 진행 중이던 다음 조합은 완료로 세지 않는다. 28조합 전체·30분 extended·네 실제 기기 실행을 통과로 주장하지 않는다.

S23 일반 저장은 b49와 d600에서 before{}/after{} unchanged true다. 기존 비어 있지 않은 프로필 복원 검사로 확대하지 않는다. Tab b49 정리 시 after는 못 읽어 blocked이며 재연결 후 별도 original-stores-after-reconnect.json에서 {}→{} 동일을 확인했다. 원래 정리 시점의 미확인은 유지한다.

## S23 반복 검사 성능과 로그

`d600.../device-1/performance-summary-reviewed.json`은 raw126샘플 중 generation+msec 중복을 제외한108개 새 샘플을 정리한다. FPS56.908~60.103, 중앙값60.000. 각300프레임 구간p95는16.666~16.667ms이며 전체600초의 단일p95라고 해석하지 않는다. 시스템23샘플의 PSS392.288~488.574MiB, 조회 가능한 양수 온도 센서32.0~51.2℃, thermal status0이다. 센서 종류별 값과 준비/재실행/정리 구간을 포함하므로 배터리/표면 온도 또는 반복 전투만의 평균으로 확대하지 않는다. 승인된 성능 합격 수치는 없으며 측정값만 보고한다.

앱 UID 로그는 검사 종료까지 살아 있고 cleanup 종료-15는 도구가 수집 process를 끝낸 값이다. 게임 충돌 exit코드로 해석하지 않는다. 자동 입력 끄기는 confirmed_disabled, offline-cleanup은 home/autoplay false/lan_eligible true다. 게임/서버 로그에서 토큰과 비밀값은 제거하고 APK·JSON·주요 PNG는 별도 build 증거에 보존한다.

원본 작업 폴더 기준2913파일의 재해시 차이0을 `original-preservation-r02.json`에서 확인했다. 전체 코드 검사·APK 검사와 실제 사용자 관측은 다른 증거이며, 사람이 새 APK를 확인하기 전에는 이전 사용자 실패를 해결 완료로 기록하지 않는다.

## 새 APK 두 기기 LAN 자동 검사

`03b5e3f0513048ed8dd6738433bcb885`는 종료2, 원시 집계8pass2blocked14미실행이다. blocked2건은 오류 문구의 시각 확인 대기이고, 오류 이벤트·실제 메뉴 복귀·입력 해제는 자동 검사에서 확인했다. 실제 네 PNG를 읽어 별도 `lan02-visual-review.json`에 pass를 남겼다. S23 초대 코드 형식 오류·없는 방·꺼진 호스트와 Tab 방 정원 초과를 합친 한 쌍 범위이며, 각 기기가 네 종류 모두 실행했다고 확대하지 않는다. 원시 blocked는 덮어쓰지 않았다.

정상 경기는 서버와 두 APK에서 승자2·종료tick4959·해시 `e78e07e67d5212d11a6f9ef1f6bc7e8de2e5e633f8cc05ec00f28baf4b7b33ff`가 일치한다. S23 HOME 뒤 새 foreground 화면·입력 해제와 두 기기 재대전 HP/기회/player 입력 초기화를 확인했다.

10초 앱 연결 단절 후 같은 슬롯1로 돌아왔고 Tab의 상대 상태도 새 offline/online으로 바뀌었다. 단절 전에는 실제 position/velocity/tick 변화가 확인된 정상 이동 입력을 보냈다. 서버는 단절tick1479/2759에 input_direction0·buffered_action빈 값을 기록했다. 65초 단절의 이탈 패배는 서버와 남은 Tab에서 승자2·종료tick6360·해시 `2a5e347e12d065db28b46e556dc937acf656f637cfbfce8752fec16bdf0bdae7`가 일치한다. S23은 lan_menu와 latest_result{}이므로 양쪽 APK가 이탈 결과 해시를 가졌다고 주장하지 않는다.

정원 테스트용 통신 참가자는 slot2에 입장하지만 실제 세 번째 APK가 아니다. 실제 Tab의 room_full 오류·화면·복귀는 확인했고 fixture의 leave_acknowledged false는 미확인이다. 방 정리 때문에 나온 추가 서버 disconnect결과tick898을 해당 ACK 또는 별도 정상 경기 통과로 사용하지 않는다.

두 기기 모두 설치 APK hash가 원본과 같고 일반 저장before{}/after{} unchanged true다. 게임·서버 로그와 주요 캡처는 해당 실행 디렉터리에 보존한다. 독립 QA도 최종 실제 LAN 증거를 감사해 통과 판정했다.

## 실제 Wi-Fi와 사용자 조작 준비

첫 수동 준비 `fa60f34c84f04fe09915acfa4dc23d17`는 자동 실행 ID의 게스트 저장을 다른 임시 API로 연결하며 demo_guest_error가 나타나 demo_nickname30초 대기 실패로 종료했다. 당시 실제 Wi-Fi 조작을 요청하기 전이었으며 준비 blocked로 보존했다. 자동 검사 통과나 제품 Wi-Fi 실패로 분류하지 않는다. 새 수동 helper는 실제 같은 APK hash를 확인한 뒤 별도 새 QA 실행 ID·저장으로 준비한다. 최초 helper의 source/context/session-error와 게임 로그는 이전 시도에 보존하며 일반 저장은 그대로 둔다.

수동 Wi-Fi 경기 `339d7f5cbf1f4434b78454b54e7819c2`는 새 QA run a4a6a2bc1d97418e9947d7c71e4db8c8에서 자동 입력을 끄고 준비했다. 사용자는 “복귀 후 이동 및 공격 가능하다.”라고 답했다. S23은 전후 boot21848 동일·경기generation1·slot1로 복귀하고 Tab도 boot26644·generation1·slot2를 유지했다. Tab의 peer_connected는 False→True로 바뀌었다. server 입력은 tick5817/6320에 방향0·대기입력빈값으로 기록됐고 해당 수동 관측에서 server-results는 빈 목록이다. 별도 manual-wifi-user-observation.json에 pass를 기록한다. 실제 Wi-Fi OFF 정확한 초 수와 Tab 문구의 사람 관측은 별도 답변이 없어 미확인으로 남긴다.

Wi-Fi 뒤 S23 무선 디버그 포트가 바뀌어 로그 일부와 종료 시 일반 저장 after는 조회하지 못했다. 그 원시 unavailable/blocked는 유지한다. 재연결 후 original-stores-after-reconnect.json에서 별도로 before{}/after_reconnect{} 일치를 확인했다. Tab 종료 저장은 {}→{} unchanged true다. 게임의 재접속 복구와 무선 디버깅 관측 공백을 구분한다. 실제 전후 경기 PNG·앱 상태·Tab peer 변화·server 입력 해제와 사용자 응답을 함께 사용하며, 단순 ADB 연결만으로 경기 복귀를 판정하지 않는다.

이후 S23만 연습 모드로 준비한 수동 artifact0ab50ed6862f46fda3812d1ec951a6ba에서 자동 입력false·실제 자현 연습을 확인하고 사용자의 조작·모션·경직·콤보·소리/진동 정상 재확인 응답을 받았다. Tab은 LAN 종료 뒤 추가 조작하지 않는다.

## 사용자 수정 재검사와 최종 집계

S23 자현의 실제 수동 재검사 응답은 방향 누른 지상 약공격 정상, 방향+회피 정상, 3단콤보 정상, 경직모션 정상, 캐릭터크기 정상, 수정 UI/HUD 정상, 음악·효과음·진동 정상이다. `0ab50.../manual-user-results.json`에 각 항목의 버전/실행 ID/기기/단계/기대값/사용자 관측값을 기록했다. 별도 직접 체감이며 소리나 진동 요청 수로 대신하지 않았다. S23 연습 정리도 종료0·자동 입력 confirmed_disabled·일반 저장{}→{} 동일이다.

`build/android-current-fixes/final-device-composite.json`은 같은 새 APK의 보존된 여러 시도에서 현재 승인 범위의 이름 있는12사례와 사용자 수정7항목을 연결한다. 단일 실행의 전체 통과라고 해석하지 않는다. S23 주 오프라인 검사/Tab LAN 상대,10분 반복,자현 사람 관측 범위이며 네 실제 기기/30분28조합·Tab 오프라인 수동 체감은 제외/미실행 기록을 유지한다.

마지막 명령 형식 점검으로 도구에 device/step/expected/observed 필드와 commands.jsonl의 요청/실제 응답·실패 기록을 추가했다. host120개 통과와 같은 APK S23의 실제 context명령 ACK를 확인했다. 게임 소스나 APK는 바꾸지 않았다. 빌드 당시2101파일은 수정 전에473MiB의 frozen-apk-source-r01 사본으로 복사해 SHA차이0을 확인했다. 이후 도구 진단 변경과 APK 입력 소스의 버전을 구분한다.

LAN 측정은 준비·경기·장애·오류·정리를 포함한다. S23 fresh25샘플FPS60.00~72.75/중앙60.00,p95구간16.666~16.939ms/PSS248.76~471.66MiB/양수sensor34.6~44.3℃,Tab fresh32샘플FPS48.59~54.26/중앙51.68,p95구간21.212~35.454ms/PSS291.34~362.72MiB/양수sensor26.2~39.1℃다. 승인 수치가 없으므로 성능 합격으로 기록하지 않는다.

Wi-Fi 최종 관측에는 neutralreset15913과 Tab의 추가False→True 전이가 포함된다. 직접 원인은 미확인이며 정확히 단일10초 끊김이었던 것으로 확대하지 않는다. 동일 경기/슬롯 복귀·입력 해제·사용자 이동/공격 가능이라는 확인 범위는 유지한다.
