# 대표 이미지 제작 상태

상태: 제작·검증 완료, 사용자 이미지 채택 승인 대기. 정식 등록·통합은 아직 완료하지 않았다.

- 요청: 00_request.md, 참조 데이터: 01_contract.md, 제작 접근: 02_image.md.
- 전용 작업 폴더: /Users/jdh/.codex/worktrees/combat-character-references/ForestArena.
- 브랜치: codex/combat-character-references. 시작 커밋: 360c6982c39746cecb11c3b46ebad363e7836aa5.
- 제작·검증 커밋: b8f8dcb4579e443ac66fe1fd329993750631adce. origin에 push했다. 승인 대기 draft PR: https://github.com/Dev-DHJang/ForestArena/pull/118 (base develop). 이미지 채택 승인 전이므로 병합하지 않았다.
- 네 캐릭터별 combat/front/side/rear 총16장을 제작했다. 최종 배치본은02_candidates/, 비교판은03_review/에 있다. 네 세트 모두 독립 시각 QA pass이며 qa.json과03_qa_r03.md에 실제 해시·관찰·한계를 기록했다.
- 콘텐츠 문서·이미지/애니메이션/QA 스킬과 대표 이미지 구조 검사 도구를 추가했다. 참조의 승인·원본·출처·해시와 몸 크기를 유지하며 생성 입력에 직접 첨부하도록 했다.
- 원본 PNG·실제 생성 프롬프트는 01_sources/에 남긴다. 초기 비율 불일치 시안은 r01/에 보존하고 정면 구성 모델을 먼저 맞추는 접근으로 변경했다.
- assets/character·manifest·CharacterData·전투·기존 모션·런타임 표시 배율은 변경하지 않았다.
- generation-index.json은 선택 원본·실제 프롬프트·실제 첨부 이미지의 경로/해시를 기록한다. 자현front-r02의 입력은 두 파생 이미지이며 승인 콘셉트 직접 첨부라고 확대 기록하지 않는다. 최종 QA는 승인 콘셉트와 직접 대조했다.
- 05_registration-plan.json은 승인 뒤 등록할16개 ID·경로·출처·권리 항목이다. installation_allowed=false이며 실제 등록은 하지 않았다. 사용자 승인·등록·병합은 남아 있다. Android 실기기는 수행하지 않았다.

## 검증 기록

- python3 tools/forest_arena/test_combat_reference.py: 8개 PASS.
- skill-creator quick_validate.py: image-design, 2d-animation, qa PASS.
- ./scripts/verify.sh --list: 변경41개에 관련 검사28개 선택(생성 중간 시점).
- ./scripts/verify.sh --full: PASS, 전체91항목 완료(가져오기1회+검사90개),538.5초. build/verification/20261029-173800-3bf8f86e/result.json. 전투·UI·네트워크·리소스·하네스·신규검사 포함. 실행 코드의 미커밋 변경을 포함한 작업 폴더를 검사했다.
- 전체 검사 뒤 설명·용어 보완은 docs 분야 검사로 확인했다. 상세 보고서는 build/verification/에 있다.
- 선택16장 원본·프롬프트·실제 입력 해시와 등록 제안의 ID 충돌·대상 미등록 확인: PASS.
- 캐릭터별 구조 검사:4세트 PASS. --require-approved는4세트 모두 예상대로 거부(사용자 채택 승인 없음).
- 이름 있는 수동 재검사: 대표 이미지 다각도 비교,128px·좌우 반전 식별,기준점 표시 비교는 독립 QA pass. 승인 참조 첨부 확인은 생성 입력의 실제 이력·해시 연결을 확인했고, 정식 승인 세트 소비는 채택 승인/등록 뒤에만 가능하다.
- 로컬 브라우저 자동 사용은 Work 설정에서 비활성화되어 화면 자동 조작 검증을 수행하지 않았다. 정지 PNG16장과 비교판은 직접 확인했다. 실제 Android·모션 재생 검사는 이번 범위가 아니다.

## 후속

사용자에게 전체·캐릭터별 비교판을 제시한다. 각 세트의 명시 승인 뒤 기록과 실제 이미지 해시를 다시 대조하고 assets/character/<id>/reference/v01/과 manifest에 등록한다. 기존 모션을 재생성하거나 게임 배율을 바꾸지 않는다. 승인 대기 변경은 draft PR로 보존하며 채택/등록 뒤 최종 통합한다. 롤백은 해당 통합 커밋을 revert한다. 아직 통합 커밋은 없다.
