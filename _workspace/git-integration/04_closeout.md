# 추가 개발 전체 Git 통합 마무리

## 결과

2026-10-18. 최신 develop의 타이틀·로딩·메뉴 기능을 유지하고 승인 모션90종·나비 별칭2 PNG·새 묘령 아이콘·Godot 부트 로고 제거를 통합했다. 나머지 미커밋 작업은 이미 병합된 코드와 비교해 누락된 최종 UI 제작 자산·전달 문서·개발 도구·승인 근거를 보존했다. 제안·미승인 시안과 실제 기능을 구분한다.

새90종은 승인 검토 원본과1,440셀의 픽셀이 같고 표시 데이터에는 새 해시·배율1.0·발 기준124를 연결했다. 자현30종·전체 SpriteFrames·전투·저장·공개 API·네트워크 형식은 최신 develop 그대로다.

## 검사

- `./scripts/verify.sh`: 종료0, `Forest Arena verification passed.`. 전투·모션·저장·메뉴·타이틀·AI 반복 대전·실제 로컬 LAN 연결·격리 검사와 온라인 API 단위 검사를 포함한다.
- 프리미엄 메뉴3,091항목, 타이틀73항목과 기존 자동 검사 통과. 현재 메뉴 자동 검사 보고서는 `premium-menu-runtime-report.json`으로 분리했고 과거 실제 렌더 보고서를 덮어쓰지 않았다.
- 문서·하네스·Godot 리소스 검사 통과. 논리 자산519개·품질별 자산25개.
- Python 기존 검사: 투명화3·모션 도구12·세션 복구6·새 게임 뼈대12개 통과.
- 원본 누적 설치 검사 `install_approved_yu_ran.py --check`는 기존 원본 폴더에서 통과했다. Git에 남긴 최종본만으로 재실행 가능한 검사는 `python3 _workspace/git-integration/verify_integration.py`다.
- APK 생성·기존 패키지 검사·실제 APK의120텍스처/manifest/표시 데이터 일치·아이콘4개·부트 설정 검사 통과. 이전 develop APK와 서명 인증서가 같다.
- 전체 로그의 SCRIPT ERROR는0개다. 기존 검사 종료 때 ObjectDB 정리 WARNING10줄과 리소스 정리 ERROR10줄, 콘셉트를 직접 이미지로 읽는 검사 WARNING4줄이 남았다. 검사 실패는 아니지만 무경고 검사라고 보고하지 않는다. 원문은 `verify-full.log`, 집계는 `checks.json`이다.
- 독립 QA가 자산·문서·패키지를 확인했다. 최종 판정은 `03_qa_r02.md`에 기록한다.

## Android 산출물과 제외

- APK: `build/android/ForestArena-debug.apk` (346,655,317 bytes).
- SHA-256: `8c021946247c3fbc1faad2da52be4662253dd004c5446d8bcba17e429bd0c4fe`.
- 런타임 소스 커밋: `f002e0b`. 이후 문서·증거만 추가했으며 APK의 실제 내용 일치도 검사했다.
- 실제 package: `com.forestarena.welllbeing`, v0.0.1, 최소API29·대상API36, arm64-v8a/x86_64, 기존 debug 서명.
- **실기기 설치·실행·터치·화면·중단/복귀·성능 검증은 사용자 요청으로 제외했다. 기기 통과를 주장하지 않는다.** APK 생성과 데스크톱/로컬 서버 자동 검사를 실제 Android 결과로 바꾸지 않는다.

## 원본 보존

원본4개 작업 폴더의 미커밋5,975파일·약1,916MiB를 목록·해시로 기록하고 다시 읽어 변경0개를 확인했다. `source-inventory.json`, `source-disposition.json`, `original-preservation.json`을 본다. Git에는 최종본·핵심 승인 기록과 재현용 검토 시트90개를 보존했다. 중간 이미지·백업·과거 실행 로그는 원본 로컬 위치에 그대로 있다.

다른 premium-menu 작업 폴더의 두 JSON 수정은 재검사 시각만 바뀌어 기존 커밋 기록을 유지했다. 별도 APK 데모 작업의7개 실행 로그도 원본에 보존했다. CSV의 CRLF는 원본 바이트를 보존하고 `.gitattributes`에 허용 규칙을 추가했다. 원본 작업 폴더의 브랜치나 미커밋 변경을 초기화하지 않았다.

## Git과 되돌리기

- 기준: `origin/develop`의 `5afa4af5f674cdf93febf3676252613027da9a8d`.
- 작업 브랜치: `codex/integrate-current-development`.
- 자산/설정: `f002e0b`, 전달 문서/도구: `6b0437b`, 승인 증거/원본 목록: `7ee5458`.
- 구현 PR: [#102](https://github.com/Dev-DHJang/ForestArena/pull/102). 필수 검사·QA 결과를 반영한 뒤 develop에 병합하고 실제 병합 SHA를 후속 기록한다.
- 되돌리기는 해당 PR 병합 커밋을 `git revert -m 1 <병합-SHA>`로 되돌리는 새 커밋·PR로 진행한다. 기기 저장·DB·기존 로컬 자료를 삭제하지 않는다.
- main 변경·강제 push·이력 재작성·원격 브랜치 삭제는 수행하지 않는다.
