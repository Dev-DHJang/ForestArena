# 조약돌 요요 작업 상태

## 현재 결과

- 전투·상점·장착/해제·프리셋·AI별 소유 장비 선택·장비 버튼·LAN5 구현.
- 대표 이미지와 전투 본체 생성·정적 이미지 독립 QA 통과. 기존 승인 캐릭터/모션 PNG는 변경하지 않았다.
- 자현·나비의 지상·공중 사용 모션4개를 _workspace 후보로 제작했다. 현재 모션별 명시 승인 전이므로 runtime/manifest에는 등록하지 않았다.
- 후보 재생: `index.html`, 정상·느린·좌우 반전 영상은 `qa-motion-r02/`. 실제 전투·표현 코드를 실행한 프레임/좌표 기록을 재구성한 자료이며 Android 화면 녹화가 아니다.

## 검증

- `tests/pebble_yoyo_combat.gd`, 장비 UI/회수 연결, 두 캐릭터 제품, 저장·AI 흐름·프리셋·프로필 카탈로그 검사 통과.
- API16개, Android fleet 도구150개, 모션 검토 도구91개 통과. 실제 Android 기기 결과가 아니다.
- 실제 LAN은 `build/verification/pebble-yoyo/lan-runtime-focused-r03.log`에서 장비 사용·무피해 경직·쿨타임·재접속·앱 흐름·결과 저장을 통과했다.
- LAN에서 발견한 기존 가변 시간 이동 문제를 수정했다. socket/deadline 처리는 _process, 권위60Hz 전투는 _physics_process로 옮기고 이동거리=속도×틱/60 회귀를 추가했다.
- 첫 전체 검사는 새 카탈로그 항목 수에 대한 과거 기대값 때문에 실패했다. 이후 잔여 검사는 Android QA의 과거 장비 차단 기대값과 실제 LAN 이동 문제를 발견했고 수정했다. 최종 `./scripts/verify.sh --full`은93개 검사와 Godot 가져오기(총94단계)를541.8초에 모두 통과했다. 결과: `build/verification/20261030-133517-8642756e/result.json`, 요약: `build/verification/pebble-yoyo/full-r02.log`.
- 기존 엔진 종료 시 ObjectDB/리소스 정리 진단은 기능 검사 통과와 별도다. 파싱·스크립트 오류를 통과로 처리하지 않는다.

## 승인·미확인

- 네 모션의 최종 독립 QA는 정상·느린·좌우 반전 재생과 전체64프레임을 확인해 모두 pass다. 검토 기록은54개 소스 해시를 고정하고 명시 catalog/scope를 지정한 --require-pass를 통과했다. 사용자 명시 승인·등록은 남아 있다. 후보는 `candidate-catalog.json`·`candidate-scope.json`, 검토 기록은 `review-r03/motion-review.json`이다.
- Android 실기기의 엄지 접근성·중단/복귀·성능은 미실행이다.

## Git·다음 작업

- 기준: c4c8dc7f52a2d72964978824ee098eb15814839f, 작업 브랜치 codex/pebble-yoyo.
- 전용 폴더: /Users/jdh/.codex/worktrees/pebble-yoyo/ForestArena. 저장 공간 부족으로 일반 체크아웃이 실패해 동일한 깨끗한 기준커밋의 추적 파일을 새 빈 폴더에 APFS copy-on-write 복제했다. 기본 폴더와 다른 작업은 수정하지 않았다. 앱 관리 작업 폴더 등록은 지원되지 않아 명시 경로를 사용한다.
- 최종 QA·검사 통과. 관련 변경만 commit/push/검토용 draft PR을 준비한다. 사용자 모션 승인 후 정식 PNG/SpriteFrames/manifest를 등록하고 관련 검사를 수행한 뒤 develop 병합한다.
- 되돌릴 때 게임·API·LAN 소비자를 같은 묶음으로 처리한다. 이미 저장된 pebble-yoyo 보유 ID를 읽을 수 있는 카탈로그 호환을 보존하며 보유 데이터를 삭제하지 않는다.
