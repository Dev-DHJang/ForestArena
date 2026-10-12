# 계획 이행 확인표 · 실기기 재검사 진행 중

최종 완료를 아직 주장하지 않는다. 사용자가 변경한 기기 역할은 S23 주 검사·Tab S5e LAN 상대다. 동일 APK를 실제로 확인한 증거만 기기 통과로 판단하며 이전 APK 통과를 새 APK 결과로 옮기지 않는다. 최초 새 APK 실패 b49ce3fd6dfc40528deeeae426611207은 사용자 조작이 섞였으므로 별도 재시도를 사용한다.

| 계획 요구 | 현재 증거 | 판정과 남은 작업 |
| --- | --- | --- |
| 대상 1~4대 명시·중복/4대 초과 오류·병렬 오프라인·홀수 LAN 제외 | PR89 android_fleet.py 및 host 자동 검사 118개, verify-integrated-r02.log | 도구 검사 완료. 실제 이번 대상은 S23과 Tab 2대이며 4대 실제 동시 실행 통과는 주장하지 않음 |
| APK·물리 기기·버전·가로 화면·무선 설치·콜드 시작 | 새 APK b49의 S23 DEV-01 pass, hardware R3CW201479A/SDK36. Tab R54R404CZYJ/SDK30은 LAN 준비에 사용 | S23 완료. LAN용 새 시도에서 두 APK 해시를 다시 확인 |
| first/0원 상점/설정/재실행·저장 분리 | 새 APK S23 UI-01 pass, AndroidQaSession·android_audio_store 자동 검사 | 완료. 일반 저장의 before/after는 빈 map 동일이며 기존 내용 복원을 검사한 증거로 확대하지 않음 |
| 네 캐릭터·없음/6장신구의 실제 경기 선택 | 새 APK S23 OFF-01 actual_match_selections·runtime_configuration pass | 선택 반영 완료. 효과 발생 자체 전수 검사는 선택 확인과 구분 |
| 실제 터치 이동/점프/약/강/특수/회피·궁극기 전후 | 새 APK S23 INPUT-01 pass·adb-touch/touch edge/실제 상태 변화 | 자동 ADB 검사 완료. 사람의 두 손가락 사용감은 별도 확인 필요 |
| BACK/HOME/복귀·입력 해제·로비 | 새 APK S23 LIFE-01 pass, 동일 boot 및 foreground·pause 재개 | 오프라인 완료. LAN 복귀는 LAN 새 시도에서 확인 |
| 정상 전투 승패·결과·재대전 HP/기회/입력 초기화 | 새 APK S23 OFF-02 pass | 완료 |
| 연습/Solo8/Team4대4/Story 프롤로그 | 새 APK S23 MODE-01의 하위 practice/solo/team/story 모두 pass | 완료. Story 보상·성장은 범위 밖 |
| 두 APK LAN 생성/참가/전투/재대전·승자/tick/hash 일치 | 코드 LAN runtime 검사는 통과, 새 APK b49 LAN은 blocked | 실제 새 LAN 시도 필요 |
| 잘못된 코드/없는 방/꺼진 서버/정원 초과 안내와 복귀 | 이전 APK 쌍별 네 화면 확인은 보존, 새 APK는 미실행 | 새 APK 실제 네 오류 화면과 복귀 확인 필요 |
| 10초 앱 LAN 단절 같은 슬롯·해제, 65초 단절 60초 이탈 패배 | 이전 APK 결과는 보존, 새 resume_pending fixture 통과 | 새 APK 실제 자동 장애 필요 |
| 10분 반복·정상 결과/재대전·고착/충돌/응답 멈춤 없음 | 최초 새 APK SOAK201.825초 fail 원본 보존; 사용자 직접 조작 확인; d6002041832f4ba6a2f37babd9907609 종료 0, SOAK608.196초/600초 설정/9판 pass | S23 반복 완료. Tab 오프라인 반복은 갱신된 목표 범위 밖 |
| extended30분·28조합 기기 배정·미완료 미실행 | 실행 도구 시간/배정 검사와 최초 새 시도 3개 결과 | extended 별도 실행 결과 없음. 실행 모드와 완료 조합 범위를 명확히 남김 |
| 실제 Wi-Fi10초·같은 경기 복귀/이탈 패배 | 이전 APK 사용자 실패와 서버/앱 증거 보존 | 새 APK 수동 재검사 필요 |
| 사용자 발견 방향+공격·모션 크기·UI·경직·콤보·BGM/SFX/진동 | 코드·renderer·독립 QA 통과, 실제 새 APK package VIBRATE/자원 포함 | S23에서 사람이 새 APK를 직접 재확인 필요. 실제 요청/재생 수를 체감 통과로 기록하지 않음 |
| 30초 화면/5분 경기/30초 변화없음·일시정지/의도 장애 제외 | runner 시간 제한 자동 검사와 실제 결과; b49 pause는 fail로 보존 | 정상 입력 상태의 반복 및 LAN 결과로 재확인 |
| pass/fail/blocked/미실행·예상 밖 ADB 단절 새 시도·이전 보존 | b49 raw results·로그·PNG 및 새 d600 별도 디렉터리 | 현재 분리 기록 완료. 마지막 전체 집계는 새 시도 뒤 작성 |
| APK/코드/기기/JSON/한국어 요약/로그/서버/캡처 | 새 b49 source-manifest/results/summary/각 기기 증거; 새 APK metadata | 생성·보존 완료. 새 LAN 서버와 최종 manual 증거는 필요 |
| FPS/p95/PSS/발열·승인 수치 없음·불가 미확인 | b49 performance.json/memory.txt/thermal.txt | 측정값 확인 및 범위 보고 필요. 성능 합격으로 단정하지 않음 |
| release 비활성/입력 초기화/저장 분리·두 서버 간 간섭 | Godot ANDROID_QA_SESSION·audio store·LAN runtime 및 native Java 검사 | 자동 검사 완료. 실제 release 설치 검사와 4대 실경기는 미실행 |
| verify/docs/LAN runtime/리소스/Android 패키지 | verify-integrated-r02.log exit0, export-r02.log 실제 APK pass | 완료. runtime 코드 변경이 없으므로 기록 추가만으로 전체 검사를 반복하지 않음 |
| 작업 기록·문서 색인·기존 작업/승인 자산 보존·원격 통합 | 00/01/02/03/04·docs/INDEX·UI문서·PR89/90 draft | 코드 QA 완료, 최종 실제 증거 감사와 develop 병합 SHA/rollback 기록 필요 |

기기 페어링·디버그 키·재접속 토큰은 기록하지 않는다. v2 게스트 API는 이번 검사용 메모리 fixture이며 개발 DB/정식 온라인 검증으로 확대하지 않는다. 실제 Wi-Fi는 사람 조작, 자동 장애는 앱 연결만 끊는다.
