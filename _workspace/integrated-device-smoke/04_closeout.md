# 최신 통합본 실기기 검사 마무리

2026-10-18. 기존 전체 개발 통합은 PR102(a2fad2dee7a7c608afd6ae8103c3ad67f62b07b1)·마무리PR103을 통해 develop에 반영됐다. 이번에는 사용자의 후속 요청으로 실제 Android 검사를 추가한다. **기본 기기 검사와 추가 화면·영상 재검사를 통과했다. 최종 독립 QA r02 PASS 뒤 PR104를 develop에 병합했다. 실제 병합 SHA는 e621d883b8c9fe55b879a5b8519c5c21fdd2e14e다.**

## 수정

r01은 APK 설치·타이틀 표시는 성공했지만 검사 도구가 없는 state.json의 안내 문자열 때문에 정상 startup.json을 읽지 못했다. r02는 설치 중 무선 연결 중단으로 blocked였다. r03은 수정 도구로 시작 진입에 성공했고 실제 상점 카드가 드래그를 막는 문제를 발견했다. 실패 기록은 attempts에 보존했다.

시작/게임 상태 독립 해석·메뉴 저장 해시 범위 확장, 카드·추천 배너 장식 입력 전달, API node_modules/dist의 APK 제외와 패키지 거부 검사를 수정했다. 공개 API·저장 형식·승인 캐릭터 자산·전투 판정은 변경하지 않았다.

## 완료된 자동 검사

- 최종 `./scripts/verify.sh` 종료0, Forest Arena verification passed. 호스트134테스트·native Pan 목록0→184·프리미엄 메뉴3091항목·타이틀73항목과 기존 전투·AI·로컬 연결·격리·API 검사를 통과했다.
- 문서·하네스·Godot 리소스 검사 통과. 논리 자산519개·품질별25개.
- 실제 APK의120텍스처·manifest/layout·아이콘4개·시작 설정과 기존 debug 서명 일치 확인. 호스트 API 빌드 파일을 담은 중간 APK를 거부하는 부정 검사도 통과했다.
- SCRIPT ERROR0, 기존 종료 시 정리 WARNING15·ERROR11이 남았다. 무경고 검사라고 표현하지 않는다. 자세한 결과는 automated-checks.json과 원문 로그를 따른다.

## 실제 Android 결과

Galaxy S23 Ultra(SM-S918N), Android16/API36 실제1대, 가로3088×1440에서 r04 smoke 종료0이다. 설치된 base.apk 해시는 최종 APK와 같다.

- DEV-01: 타이틀 준비·첫 선택 진입 PASS.
- UI-01: 실제 스크롤·네 캐릭터/여섯 장신구 획득·설정 적용·재실행 복원 PASS.
- OFF-01: 네 캐릭터와 장신구7상태의11개 실제 경기 설정 PASS.
- INPUT-01: 실제 기본 입력·방향+회피·준비 전 궁극기 거부·정상 전투로 게이지를 얻은 뒤 궁극기 PASS.
- LIFE-01: Back 일시정지·계속하기, Home 이동·복귀와 입력 해제 PASS.
- OFF-02: 정상 전투 결과·재대전 체력/남은 기회/입력 초기화 PASS.
- MODE-01: 연습·8인 개인전·4대4 팀전·Story 프롤로그 진입과 준비 복귀 PASS. 개인전/팀전은 정상 전투 결과까지 확인했다. Story 대화·보상·성장 완료로 표현하지 않는다.

일반 저장13경로는 검사 전후 모두 파일이 없어 before={}·after={}·unchanged=true다. 존재하는 저장13파일의 호환성을 검증한 결과로 표현하지 않는다. QA 별도 경로에서 보유·설정을 만들고 재실행 복원을 확인했다. 실제 터치는 ADB 입력, 대전 조건 설정과 결과까지의 자동 전투는 debug QA 명령을 사용한다.

[기본 결과](physical/r04/summary.md)와 화면·세부 상태는 physical/r04에 기기 식별자·IP를 가린 사본을 저장했다. 원본은 로컬 artifacts/android-fleet/integrated-smoke-r04에 보존했다. 독립 QA r01은 기본 smoke PASS다. 추가 검사는 physical-capture-summary.json과 최종 QA r02를 따른다.

## 추가 화면·영상 확인

사용자의 무선 재연결 뒤 같은 기기임을 확인하고 남은 검사만 진행했다. 타이틀3회 새 실행·준비 완료·실제 터치 로비 진입, 메뉴13개 진입/뒤로 복귀, 추천 배너·장신구·도감 본문 드래그3곳, 네 캐릭터 전투/새 점프 상태와 실제 화면을 확인했다. 각 영상은 약12초의H264 1544×720이며 원본 파일·해시·ffprobe 결과를 남겼다. 직접 검토한 시작 구간에서 새 묘령 native 시작 아이콘·진행하는 로딩바·숲 타이틀이 보이고 Godot 로고는 보이지 않았다.

Android 앱 정보의 실제 InstalledAppDetails 화면과 새 묘령 아이콘도 확인했다. 개인 홈 화면의 런처 배치·모든 마스크를 확인한 결과로 확대하지 않는다. 친구·랭크는 현재 계정 연결 안내 화면 표시까지 확인했으며 서버 기능이 구현·통과됐다는 의미가 아니다.

첫 추가 실행은 무선 단절로 시작 전에 blocked였다. 재연결한 추가 실행은 시작3·메뉴13·드래그3을 통과했으나 메뉴용300ms대기 뒤 묘령의 짧은 점프 상태를 놓쳐 fail로 남겼다. 실제 전투 기록에는 점프/착지가 있었으며, 짧은 점프를 실제 tap 직후 새 msec에서 확인하도록 검사 도구를 고쳐 네 캐릭터를 재확인했다. 일부 자현 PNG 누락도 확인해 화면 저장 성공을 필수로 검사하고 자현 두 장을 다시 확보했다. 앱 정보의 최초 조기 촬영은 실제 로비였으므로 invalid로 표시해 보존하고, -W 및 실제 Settings 최상위 화면 확인 뒤 다시 촬영했다.

최종 캐릭터 화면은 자현 supplemental-ja-r04와 나머지3캐릭터 supplemental-r03의8장이다. 네 캐릭터 ID·새 msec·같은 경기·jump 리소스의 실제 표시·PNG 존재를 집계에서 검사했다. 모든 추가 실행 전후 일반 저장은 파일 없음 상태를 유지했다. 실패·무선 중단·조기 촬영·재검사 원본을 덮어쓰지 않았다.

## 미실행 범위

두 실기기 LAN3항목·장시간 반복/성능·사람의 동시 터치/소리/진동·전체90모션 개별 시각 품질은 이번 간단 검사에서 미실행이다. 측정값만으로 성능 통과를 주장하지 않는다.

## APK·Git·원본

- APK: build/android/ForestArena-integrated-device.apk, 346655401bytes.
- SHA-256: ae579f8ed372c32f79c479edebb1a671047e7b4d1467ce9f0f06997fd55df6df.
- 런타임 소스:1004c981f577621c4bf5f2bdc2091921fa9e7ee1. 이후 변경은 검사 도구·기록이며 앱 런타임은 같다.
- 앱 ID com.forestarena.welllbeing, 버전0.0.1, 최소API29·대상API36, arm64-v8a/x86_64, 이전 debug 인증서 유지.
- 작업 브랜치 codex/integrated-device-smoke, 기준 develop2c22ce60a86d418268fbd19bd91f16db57055a2b. 수정 커밋 df17caa·2637ad6·023c451·1004c98, 검사 준비6f498e8.
- [PR104](https://github.com/Dev-DHJang/ForestArena/pull/104)는 최종 증거·독립 QA r02 PASS와 예상 head122a2412387fc6c8d8049fb3041f0df87e6bb31f를 확인해 표준 merge 방식으로 develop에 병합했다. 실제 병합 SHA는 e621d883b8c9fe55b879a5b8519c5c21fdd2e14e다. 원격 등록 상태 검사·워크플로 실행은 비어 있었으며 이를 원격 CI 통과라고 말하지 않는다. 되돌리기는 `git revert -m 1 e621d883b8c9fe55b879a5b8519c5c21fdd2e14e`를 적용하는 새 커밋·PR로 진행한다. 현재 브랜치를 강제로 되돌리거나 이력을 재작성하지 않는다.
- 기존 제작 자료5975파일·2009473912bytes 재비교 결과 변경0이다. original-preservation.json을 본다. 원본 작업 폴더·기존 APK·백업·중간 파일은 보존했다. main·기기 저장·DB 초기화·강제 push·원격 브랜치 삭제는 수행하지 않았다.

이번 마무리 문서는 최신 develop의 실제 병합 결과를 codex/integrated-device-closeout 브랜치에서 보완한다. 앱 런타임·승인 자산·APK는 변경하지 않는다.
