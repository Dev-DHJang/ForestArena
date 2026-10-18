# 통합 판단과 원본 보존

- 기준 develop: 5afa4af5f674cdf93febf3676252613027da9a8d. 원본 작업 폴더의 HEAD는423b1a8로 이전 상태다. 새 작업 브랜치는 codex/integrate-current-development다.
- 원본 tracked 변경과 브랜딩 변경을 합쳐49개는 최신 develop과 이미 같고,6개는 양쪽을 비교해 같은 결과로 합쳐졌다. 실제 새 표현 변경은 승인90종과 나비 별칭2 PNG, manifest, 표시 데이터, 브랜딩 설정이다.
- 최신 develop에 이미 있는 장신구 정책·캐릭터 외형·투명화·점프 표시·세션 복구·경제 제안·개발 도구를 오래된 복사본으로 되돌리지 않는다. README·ADR·메뉴·전투·서버 코드와 기존 검사를 보존한다.
- INDEX는 두 새 안내 항목만 추가하고 기존 타이틀·런타임 메뉴·자동 검사 안내를 유지한다. docs/ui/premium-menu-v07.md는 최신 develop이 과거 로컬 설계본보다 새로우므로 최신본을 유지한다.
- 승인된 PNG의 실제 픽셀, manifest와 기존 승인 기록을 수정하지 않고 복사했다. 표시 데이터만 새 그림의 해시와 승인 배율로 갱신했다. 자현30개의 그림·표시 데이터와 전체 SpriteFrames는 develop 그대로다.
- 새 코드/API 개발은 하지 않는다. 누락된 전달 문서·최종 UI 제작 자산·새 게임 뼈대 도구/ZIP과 요청·승인·출처·QA 기록을 보존한다. 과거 pending 기록은 당시 사실이며 최신 approval-all과 완료 문서가 이후 상태를 설명한다.

source-inventory.json은 기존4개 작업 폴더의 미커밋 파일5,975개·약1,916MiB의 원본 위치·크기·SHA-256을 기록한다. selected-files.json은 복사한 최종본·핵심 기록과 승인 검토 시트90개의 선정 근거다. 중간 이미지·백업·과거 로그는 기존 로컬 위치에 보존하며 삭제하지 않는다. 과거 전체 설치 도구는 원본 작업 폴더의 전체 중간물·백업을 요구하므로 재현 가능한 현재 검사는 verify_integration.py를 사용한다.

실기기 설치·실행·ADB 조작은 하지 않는다. 사용자 요청으로 제외된 항목이며 이번 자동 검사 결과와 분리한다.

추가 보존: 다른 premium-menu 작업 폴더의 미커밋 두 JSON은 재검사 checked_at만 다르므로 원본과 기존 커밋을 유지했다. 별도 APK 데모 작업 폴더의7개 과거 실행 로그도 중간물로 로컬에 보존한다. 전체 기본 검사에서 생성한 headless 메뉴 결과는 별도 파일로 보존하고 과거 실제 렌더 보고서를 복원했다. CSV CRLF는 .gitattributes로 허용해 원본 바이트를 바꾸지 않았다.

최종 전체 diff 검사에서 과거 forestlight-polish-v04 SVG의 생성된 빈 줄45곳에 공백이 있음을 확인했다. manifest 해시가 연결된 원본 바이트를 고치지 않고 해당 보관 SVG 경로에만 whitespace=-blank-at-eol을 지정했다. 작업 중 생성한 Git push 로그 복사본의 끝 공백은 정리했다. 전체 PR diff의 whitespace 검사를 다시 통과했다.
