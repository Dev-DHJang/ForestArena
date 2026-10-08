# 대전 미니맵 작업 마무리

## 구현 결과

우측 상단 240×150 미니맵에 전체 지형·실시간 위치·승인 얼굴·사용자명을 연결했다. 팀전은 내 팀 파랑·상대 빨강, 개인전·1대1은 흰색이며 내 위치 삼각형은 마지막에 그려 겹친 얼굴에도 보인다. 얼굴/점, 이름 켜기·끄기, 전체 투명도, 닉네임을 설정·미리보기·저장할 수 있다. 설정은 다음 경기, LAN 이름은 방 입장부터 적용한다.

기기·DB 프로필 v3 이전은 기존 보유·선택·접근성 값을 보존한다. 기기 이전 원본은 .bak에 보관한다. DB 기록·이전 요청 응답도 v3으로 읽을 수 있고 중복 저장·동시 변경 보호는 유지한다. LAN은 기존 protocol_version 1을 유지하며 이름만 선택적으로 추가해 재접속·재대전에 보존한다.

## 검증

- `./scripts/verify.sh`: PASS. 새 미니맵·실제 앱 설정 흐름·기존 전투/AI/입력/리소스·두 실제 LAN 앱·온라인 계약·문서·하네스 전체 확인.
- `./scripts/verify-docs.sh`, `./scripts/verify-harness.sh`, `python3 tools/forest_arena/verify_godot_resources.py --project-root .`: PASS. 논리 자산 350개, 품질별 자산 24개.
- `npm --prefix server/api test`: PASS, 8개 단위 검사.
- `./scripts/verify-db-profile-runtime.sh`: PASS. 별도 API 포트 3001에서 실제 PostgreSQL 저장·재실행 복원·SQL 일치·실패/재시도·동시 변경·v2 DB 행 이전·이전 v2 요청 응답 재시도 확인. 기존 포트 3000 API는 재시작하지 않았다.
- `./scripts/verify-lan-runtime.sh`: PASS. 두 클라이언트의 이름 정규화·재접속·재대전 유지와 실제 호스트/참가자 앱의 내 위치 연결 확인.
- `godot --path . --script res://tools/forest_arena/render_battle_minimap_app.gd`: 실제 렌더 화면 4개를 screens/에 기록. 2명 얼굴 16:9, 8명 팀전 최대 글씨 16:9, 8명 개인전 점·이름 숨김 20:9, 설정 미리보기 확인.
- 독립 QA: `03_qa_r01.md` fix의 삼각형 가림·LAN 줄바꿈 검증 차이를 해결한 뒤 `03_qa_r02.md` pass.
- 새로 바꾼 삼각형·기기 이전 백업은 해당 미니맵/LocalStore 검사를 다시 실행해 PASS. 기존 일부 앱 검사 종료의 ObjectDB 경고는 남지만 SCRIPT ERROR/ERROR 없이 종료했다.

## 미확인

`adb devices`에 연결 기기가 없어 물리 Android 안전 영역·멀티터치·프레임 성능은 미실행이다. 데스크톱 화면 확인과 Android 기기 통과를 구분한다. Story 성장·경제·정식 온라인 범위는 추가하지 않았다.

## 버전 관리와 되돌리기

최신 origin/develop c938dc5에서 feature/battle-minimap 브랜치를 만들었다. 원래 폴더의 캐릭터 모션 등 미커밋 변경은 포함하지 않았다. 구현 commit은 `f55fdb362b035f50eba2f9b2d5dacb0ffb758e88`이다. [구현 PR #67](https://github.com/Dev-DHJang/ForestArena/pull/67)은 2026-10-08 17:20 KST에 develop으로 병합됐으며 병합 SHA는 `1c59c3443035f86a2359dcadab2087dd4bbed1a5`다. GitHub state=MERGED와 origin/develop 이력을 다시 읽어 확인했다. 원격 자동 CI 항목은 없으며 위 로컬·실제 연결 검사 결과와 독립 QA로 확인했다.

병합 증거를 기록하는 별도 docs/battle-minimap-closeout 브랜치의 문서 PR은 구현을 바꾸지 않는다. 원래 작업 폴더는 사용자 미커밋 변경 때문에 자동으로 전환하거나 덮어쓰지 않았다. 구현을 확인할 수 있는 작업 폴더는 `/Users/jdh/.codex/worktrees/battle-minimap/ForestTales`이며 `godot --path /Users/jdh/.codex/worktrees/battle-minimap/ForestTales`로 실행할 수 있다.

병합을 되돌리는 Git 명령은 `git revert -m 1 1c59c3443035f86a2359dcadab2087dd4bbed1a5`이며 실제 실행하지 않았다. 프로필 형식 되돌리기는 아래 주의를 먼저 따른다.

코드를 되돌릴 때는 이번 구현 묶음을 함께 revert한다. v3 프로필은 이전 앱이 읽을 수 없으므로 이전 코드로 실행하기 전에 기기는 유효한 이전 .bak를 보관·복원하거나 v3 복사본에서 nickname/minimap을 제거하고 schema_version=2로 변환한다. DB도 대상 프로필 백업 후 같은 필드를 제거한 v2 복사본으로 이전해야 한다. 실제 사용자 데이터를 자동 삭제하지 않는다.
