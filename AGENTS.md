# Forest Arena 에이전트 가이드

## 프로젝트 기준

- Forest Arena는 Godot 4 기반 Android 우선 2D 플랫폼 아레나 격투게임이다. 가로 화면과 터치가 제품 기준이며 데스크톱 입력은 개발·검증용이다.
- 문서 위치와 읽는 순서는 `docs/INDEX.md`에서 찾는다. 내용이 충돌하면 `README.md`, 색인에 연결된 분야별 문서, 사용자가 승인한 `docs/product/decisions.md`의 결정 순서로 판단한다.
- Phase 5까지 완료했고 Phase 6 오프라인 전체 흐름을 진행 중이다. Story 대화·보상·성장·경제는 미구현이며 ADR-026의 로컬 2인 온라인 기술 기반과 ADR-029의 개발용 DB 프로필 저장만 선행 예외다.

## 작업 원칙

- 문서와 작업 기록은 가능한 쉬운 한국어를 먼저 쓴다. 코드·도구에서 검색해야 하는 전문 용어는 유지하되 첫 등장에 쉬운 뜻을 붙이고, 두 문서 이상에서 반복되면 `docs/GLOSSARY.md`에 추가한다.
- `권위`, `소비`, `주입`, `영속`, `게이트`, `수용 기준`, `회귀`처럼 일반적인 뜻과 다르게 쓰는 말은 설명 없이 단독으로 쓰지 않는다.
- 모든 작업은 `_workspace/<topic>/00_request.md`와 `04_closeout.md`를 남긴다. 여러 코드가 함께 쓰는 데이터 변경, 역할 간 전달, 별도 품질 확인 기록은 필요할 때만 팀 명세의 이름으로 추가한다.
- 새 기능에는 자동 테스트 또는 이름을 붙인 수동 재검사를 포함한다. 실제 Android 기기로 확인하지 않은 결과는 기기 통과로 기록하지 않는다.
- 역할과 라우팅은 `docs/operations/harness/team-spec.md`가 단일 원본이며, 현재 단계·명령·미확인 항목은 `docs/operations/harness/operating-index.md`를 따른다.
- 기본 검사는 `./scripts/verify.sh`다. 문서 변경은 `./scripts/verify-docs.sh`, AI 역할 체계 변경은 `./scripts/verify-harness.sh`도 실행한다.
- 비전투 UI는 `docs/ui/non-combat-ui-v01.json`, `assets/ui/asset-requirements.csv`, `docs/ui/penpot-setup.md`를 기준으로 한다.

## Codex 대화 로딩 시간 초과

- 사용자가 세션 ID와 메시지 로딩 시간 초과를 알리면 [세션 복구 절차](docs/operations/codex-session-recovery.md)를 먼저 따른다. 이전 채팅을 읽을 수 없어도 진행한다.
- 프로젝트 루트에서 `python3 tools/forest_arena/recover_codex_session.py repair <세션-ID>`로 해당 세션만 백업·복구한다. 실행 결과는 요약하고 원본 대화나 이미지 문자열 전체를 출력하지 않는다.
- 복구 뒤 다른 채팅으로 이동했다가 해당 세션을 다시 열고 사용자에게 화면 표시 여부를 확인한다. 서버 조회 성공만으로 해결됐다고 말하지 않는다. Goal·승인·사용량 제한은 별도로 확인하며 자동 변경하지 않는다.
- 이미지 전달은 파일 업로드를 우선한다. 대용량 base64, 전체 이미지 diff, 긴 도구 출력은 대화에 반복 저장하지 않는다. 이 절차는 앱의 자동 기록까지 제어하지 못하므로 재발하면 같은 명령을 다시 실행한다.

<!-- FOREST_ARENA_GODOT:START -->
## Godot 리소스 경계

- 리소스 규칙과 검증: `.agents/skills/forest-arena-godot-resources/SKILL.md`, `docs/engineering/godot/setup.md`, `docs/engineering/godot/resource-rules.md`.
- `ForestArenaResources`와 `forest_arena/data/resource_registry.json`의 논리 ID만 사용하고, 기존 승인 캐릭터·생성 UI 자산을 대체하지 않는다.
- 리소스 또는 이를 소비하는 Godot UI 변경 뒤 `python tools/forest_arena/verify_godot_resources.py --project-root .`를 실행한다.
<!-- FOREST_ARENA_GODOT:END -->
