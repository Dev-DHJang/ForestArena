# Forest Arena Penpot 설계 기준

이 문서는 `Forest_Arena` 프로젝트의 `Forest_Arena_UI` 파일에서 비전투 화면과 전투 표현 UI를 설계하기 위한 작업 계약이다. Phase 2 종료 시점에는 설계 계약과 카탈로그만 존재하며, Penpot 편집은 사용자 요청으로 수행할 수 있지만 Godot 화면·이미지·계정·경제·온라인 기능 구현은 후속 작업이다.

## 권위 원본

- 화면·제품 규칙: [non-combat-ui-v01.json](non-combat-ui-v01.json)
- 전투 표현·터치 기준: [combat-ui-v01.json](combat-ui-v01.json)
- 요구 에셋·출력 경로: [asset-requirements.csv](../../assets/ui/asset-requirements.csv)
- UI 작업 절차: `forest-arena-ui/references/penpot-workflow.md`
- Penpot 제작 프롬프트: `forest-arena-ui/templates/penpot-master-prompt.md`
- 이미지 배치 프롬프트: `forest-arena-image-design/templates/ui-image-batch-prompt.md`

충돌 시 승인된 ADR과 제품 문서가 우선한다. 기존 승인 캐릭터 자현·묘령·나비와 3등신 시각 방향은 일반적인 신규 로스터 설명보다 우선한다.

## 설계와 런타임 기준

- Penpot 기준: 1920×1080 가로 화면, 8px 간격 리듬, 큰 터치 대상과 safe area.
- Godot 런타임: 1280×720 논리 해상도를 변경하지 않는다.
- 방향: 밝은 비픽셀 판타지 숲, 하늘색·민트·초록·코발트·따뜻한 금색, 반투명 유리·조각 나무·밝은 석재.
- 로고: `FOREST ARENA`.
- `SCR_01_Splash`: 캐릭터 금지. 환경·로고·로딩만 사용한다.
- 장신구: 등급·희귀도 없음. 별, 티어, 희귀도 색상 테두리, 전설/영웅 라벨을 사용하지 않는다.
- 누락 자산: 정확한 `IMG/...` 이름의 비율 보존 플레이스홀더를 만들고 보이는 `MISSING ASSETS` 목록에 기록한다.
- 전투 HUD와 경기장 UI는 `combat-ui-v01.json`에 한해 설계할 수 있다. HUD는 전투 결과를 계산하지 않으며 Phase 3 이후 조작 버튼을 현재 작동하는 UI처럼 표시하지 않는다.

## Local Penpot MCP

Node.js 22를 권장하고 20 이상을 사용한다. 저장소의 시작 스크립트는 다음 공식 명령만 실행한다.

```sh
./scripts/start-penpot-mcp.sh
```

동등한 명령은 `npx -y @penpot/mcp@stable`이다. Penpot에서 `Plugins → Load from URL`을 선택해 `http://localhost:4400/manifest.json`을 로드하고 플러그인의 MCP 연결을 활성화한다. Codex MCP URL은 `http://localhost:4401/mcp`다.

프로젝트 설정 예시는 `.codex/config.toml.example`에 있으며 비밀을 포함하지 않는다. 원격 MCP key는 비밀번호로 취급하고 저장소·프롬프트·스크린샷에 넣지 않는다.

공식 참고: [Penpot MCP 안내](https://help.penpot.app/mcp/), [OpenAI MCP 문서](https://learn.chatgpt.com/docs/extend/mcp).

## 안전한 작업 순서

1. 현재 열린 Penpot 파일과 페이지를 읽기 전용으로 확인한다.
2. 대상이 `Forest_Arena` / `Forest_Arena_UI`가 아니면 수정하지 않는다.
3. 기존 페이지, 토큰, 컴포넌트와 프레임을 목록화한다.
4. Foundations → reusable components → 24 screens → Assets Mapping → Dev Handoff 순서로 작업한다.
5. 재실행 시 기존 구조를 재사용하고 중복 생성하지 않는다.
6. 삭제·덮어쓰기처럼 복구하기 어려운 변경 전에는 대상을 확인하고 승인을 받는다.

## 구현 게이트

- Phase 2 종료 시점에는 계약과 플레이스홀더 설계만 존재한다. 실제 Penpot 편집과 Godot 화면 구현은 별도 요청과 해당 Phase 기준이 필요하다.
- 오프라인 흐름은 Phase 6 종료 기준과 별도 구현 요청이 필요하다.
- 온라인 파티·매칭·랭크·소셜은 Phase 7과 accepted 네트워크 ADR 전 구현하지 않는다.
- 계정, 상점, 경제, 영속 진행은 각각 별도 제품 승인과 계약이 필요하다.
- 캐릭터 신규 콘셉트는 `forest-arena-character-design`의 사용자 승인 게이트를 통과해야 한다.

## 완료 보고

Penpot 후속 작업은 페이지/섹션 수, 실제 컴포넌트 수, 화면 24개 충족 여부, 누락 에셋과 플레이스홀더 수, 미해결 결정, MCP 제한을 보고한다. 외부 Penpot 파일을 실제로 수정하지 않았다면 완료로 기록하지 않는다.
