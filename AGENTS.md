# Forest Arena 에이전트 가이드

- Godot 4 기반 Android 우선 2D 플랫폼 아레나 격투게임이다. 가로 화면·터치가 제품 기준이다. 현재 단계와 미확인은 `docs/operations/harness/operating-index.md`에서 확인한다.
- 문서는 `docs/INDEX.md`에서 필요한 분야만 찾는다. 충돌 시 `README.md`, 분야별 기준 문서, 사용자가 승인한 `docs/product/decisions.md` 순으로 판단한다. 과거 작업 기록을 현재 규칙으로 복사하지 않는다.
- 문서와 작업 기록은 가능한 쉬운 한국어를 먼저 쓴다. 검색용 전문 용어는 첫 등장에 뜻을 설명하고 두 문서 이상에서 반복되면 `docs/GLOSSARY.md`에 추가한다.
- 모든 작업에 `_workspace/<topic>/00_request.md`와 `04_closeout.md`를 남긴다. 추가 계약·인계·독립 검토 기록은 필요할 때만 `docs/operations/harness/team-spec.md`에 따라 작성한다.
- 코드 수정 채팅은 전용 Git 작업 폴더(worktree)를 쓴다. 시작 시 `python3 tools/forest_arena/workflow.py status`로 폴더·브랜치·기준 커밋을 확인한다. 기본 폴더는 최신 통합본 확인용이다. 다른 폴더의 파일 전체를 덮어 복사하지 않는다.
- 기본 검사 `./scripts/verify.sh`는 변경 관련 검사다. `--list`로 선택 이유를 확인하고, 최종 통합·병합 전 `--full`을 실행한다. 분야별 검사는 `--suite <이름>`이다. 같은 코드의 통과 검사를 이유 없이 반복하지 않는다.
- 단순 변경은 한 에이전트와 관련 스킬만 사용한다. 독립 검토가 필요한 변경·역할·원격 통합 절차는 `docs/operations/harness/team-spec.md`, 검사·동시 작업·정리 절차는 `docs/operations/project-maintenance.md`를 따른다.
- 새 기능에는 자동 검사 또는 이름 있는 수동 재검사를 포함한다. 실제 Android에서 수행하지 않은 결과를 기기 통과로 기록하지 않는다. 긴 로그는 파일에 저장하고 대화에는 결과와 조치만 요약한다.
- 비전투 UI 기준은 `docs/ui/non-combat-ui-v01.json`, `assets/ui/asset-requirements.csv`, `docs/ui/penpot-setup.md`다. 승인 캐릭터·모션의 개별 승인 규칙은 해당 스킬을 따른다.
- 세션 ID와 메시지 로딩 시간 초과를 알리면 `docs/operations/codex-session-recovery.md`를 먼저 따른다. 원본 대화·이미지 문자열을 출력하지 않으며 복구 뒤 실제 화면 표시를 확인한다.

<!-- FOREST_ARENA_GODOT:START -->
## Godot 리소스 경계

- 규칙과 검사: `.agents/skills/forest-arena-godot-resources/SKILL.md`, `docs/engineering/godot/setup.md`, `docs/engineering/godot/resource-rules.md`.
- `ForestArenaResources`와 `forest_arena/data/resource_registry.json`의 논리 ID만 사용하고 기존 승인 캐릭터·생성 UI 자산을 대체하지 않는다.
- 리소스 또는 이를 사용하는 Godot UI 변경 뒤 `python3 tools/forest_arena/verify_godot_resources.py --project-root .`를 실행한다. 변경 관련 검사에 포함돼 통과했으면 별도로 반복하지 않는다.
<!-- FOREST_ARENA_GODOT:END -->
