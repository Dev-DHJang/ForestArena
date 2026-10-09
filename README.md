# Forest Arena

Forest Arena는 발판이 있는 경기장에서 3등신 동물 캐릭터가 상대를 밖으로 밀어내는 Android용 2D 격투게임이다. Godot 4로 개발하며, Phase 5까지 완료한 전투 기반 위에서 오프라인 전체 흐름과 같은 Wi-Fi LAN 1대1을 개발하고 있다.

게임 개발 용어가 낯설다면 [용어 가이드](docs/GLOSSARY.md)를 먼저 읽는다. 본문은 쉬운 표현을 우선하고, 코드에서 검색해야 하는 고유 이름은 `AttackData`처럼 그대로 쓴다.

문서나 주요 파일을 찾을 때는 [문서·파일 색인](docs/INDEX.md)에서 목적별 목록과 권장 읽기 순서를 확인한다.

## 문서 우선순위

충돌이 있을 때 아래 순서로 판단한다.

1. 이 README의 현재 프로젝트 기준
2. [문서·파일 색인](docs/INDEX.md)에 연결된 제품·게임플레이·엔지니어링·콘텐츠 문서
3. 사용자가 승인한 [결정 기록](docs/product/decisions.md)의 `accepted` 결정
4. [AI 역할과 작업 배정](docs/operations/harness/team-spec.md)
5. 작업별 `_workspace/<topic>/` 작업 기록

아직 정하지 않은 항목은 `proposed`(제안) 상태의 결정 기록으로 남긴다. 같은 규칙을 여러 문서에 복사하지 않고 최종 기준이 되는 한 문서로 연결한다. 상태와 ADR의 뜻은 [용어 가이드](docs/GLOSSARY.md#프로젝트-진행-용어)에서 확인할 수 있다.

## 문서 지도

- [전체 문서·파일 색인](docs/INDEX.md)
- [제품 비전](docs/product/vision.md)
- [게임 디자인](docs/gameplay/combat.md)
- [기능과 UX](docs/gameplay/features-and-ux.md)
- [기술 아키텍처](docs/engineering/architecture.md)
- [콘텐츠·아트·오디오](docs/content/art-and-audio.md) · [음악과 효과음](docs/content/audio-v01.md)
- [캐릭터 외형 계약 v01](docs/contracts/character-appearance-v01.json)
- [개발 순서와 완료 조건](docs/product/roadmap.md)
- [AI 개발 가이드](docs/operations/ai-development.md)
- [세계관과 중심 서사](docs/product/world-and-story.md)
- [용어 가이드](docs/GLOSSARY.md)
- [결정 기록](docs/product/decisions.md)
- [비전투 UI·Penpot 설계 기준](docs/ui/penpot-setup.md)
- [하네스 운영 색인](docs/operations/harness/operating-index.md)

## 실행과 검증

    godot --path . --editor
    ./scripts/verify.sh
    ./scripts/verify-lan-runtime.sh
    ./scripts/lan-host.sh start
    ./scripts/server-dev.sh up
    ./scripts/admin-dev.sh setup
    ./scripts/admin-dev.sh build
    ./scripts/verify-db-profile-runtime.sh
    ./scripts/verify-online-server.sh
    ./scripts/server-dev.sh verify-runtime
    ./scripts/export-debug-android.sh
    ./scripts/verify-android-emulator.sh
    ./scripts/android-wireless-debug.sh devices

실제 Android 기기를 무선으로 연결하는 방법은 [Android 무선 디버깅](docs/engineering/godot/android-wireless-debugging.md)을 참고한다.
같은 Wi-Fi의 Android 사용자 두 명이 대전하는 방법은 [LAN 1대1 플레이](docs/gameplay/lan-1v1-play.md)를 참고한다.

`./scripts/verify.sh`는 화면 없이 Godot 프로젝트 열기, 앱 기본 실행, 전투, 캐릭터·직업·장신구 조합, 로컬 온라인 계약, 데이터 형식과 문서 구조를 한 번에 확인하는 기본 검사다. `./scripts/server-dev.sh verify-runtime`은 실행 중인 로컬 스택에 실제 Godot 클라이언트 두 개를 붙여 매칭·입력·재접속·결과 저장을 확인한다. `./scripts/verify-docs.sh`는 문서 위치·링크·쉬운 문장 규칙을, `./scripts/verify-harness.sh`는 AI 역할·작업 배정 규칙을 빠르게 확인한다.

관리자 웹의 최초 계정·실행·복구는 [로컬 관리자 웹](docs/engineering/admin-web.md)을 참고한다.

## 현재 상태

- 개발용 DB 저장: 첫 선택·로비의 `저장 모드`에서 `로컬 DB 연결`을 선택한다.
  기본 주소는 `http://127.0.0.1:3000`이며 보유·선택·접근성 설정을 API를 통해
  PostgreSQL에 저장한다. DB가 비어 있으면 유효한 기기 저장을 한 번 이전하고 원본은 보존한다.
  DB 모드는 다음 실행에도 복원되며 저장 실패 시 재시도를 안내한다.

- 로컬 플레이: 첫 캐릭터 지급, 0원 상점·기기 저장, 네 캐릭터와 장신구 선택, AI·연습·
  최대 8명 Solo·Team 경기, 결과·재대전이 연결됐다. Story는 보상·성장이 없는 프롤로그로
  명시한다. [로컬 AI 안내](docs/gameplay/local-ai-play.md)를 참고한다.
- 무료 APK 데모: 기존 debug 앱 ID・서명을 유지하고 같은 네트워크의 1대1 한 경기를
  Mac 한 대에서 운영한다. 게스트 인증・중복 없는 닉네임은 별도 데모 PostgreSQL에 저장하고
  기존 무료 보유・설정은 기기에 남긴다. [데모 설치 안내](docs/gameplay/demo-install.md)를 따른다.
  물리 Android 두 대의 최종 확인이 남아 있으면 데모 출시 완료로 처리하지 않는다.
- 완료: 같은 입력이면 같은 결과가 나오는 기본 전투 한 판(Phase 1), 캐릭터·직업·장신구를 조합하는 데이터 처리(Phase 2), 서로 다른 전투 스타일 비교(Phase 3), 장신구 조건·기술 교체·태그 시너지 검증(Phase 4), 부모·현재 직업의 기술·규칙·효과 누적 검증(Phase 5).
- 현재: AI 작업은 14개 전문 역할로 나눈다. 패키징·스토어 출시, Story 대화·보상·성장,
  게임 재화와 정식 인터넷 온라인은 이번 완료 범위에서 제외한다.
- 준비된 캐릭터 자료: 자현·묘령·나비·유란의 기본 데이터, 콘셉트와 기본 MoveSet용
  승인 런타임 모션이 실제 전투 화면에 연결됐다.
- 공격 체계: 세 캐릭터의 공격 정보는 `AttackData`(공격 시간·피해·밀어내기)와 `MoveSetData`(기술과 입력 조건)에 저장되어 있다. 실제 기본 공격과 맞음 계산, 터치 입력이 동작한다.
- 화면과 지형: 승인 Forestlight 터치 조작 이미지와 5개 충돌면에 맞춘 숲 경기장 지형을
  Godot 논리 자산 ID로 연결했다. 24개 장기 화면 계약과 Penpot 원본은 별도 설계 기준으로 유지한다.
- 로컬 검증 완료: Android debug APK export, arm64 에뮬레이터 설치·가로 실행·대전 진입·
  터치·중단/복귀와 20:9 시각 검사.
- 미확인: 최신 전체 모션 묶음의 실제 물리 Android 기기 터치·중단/복귀·성능 재검.
- 개발 기반: 기존 PostgreSQL·TypeScript 개발 흐름을 유지하며, 별도 데모 DB/API와 Godot LAN headless
  서버가 네 캐릭터·장신구 6종의 1대1을 60Hz로 판정하고 20Hz 상태를 전송한다.
- 미구현: Story 대화·보상·성장·경제, 복수 장신구 동시 장착, 클라우드·8인 정식 온라인,
  출시용 서명·AAB·스토어 등록.

음원 생성·신호 검사는 Python NumPy와 ffmpeg가 필요하다. `python3 tools/forest_arena/verify_audio_v01.py`로 음원 파일·출처 확인값·반복 경계를 검사한다.
