# 대표 이미지 제작 상태

상태: 제작·사용자 채택·정식 참조 등록·등록 후 검증 완료. 원격 통합 결과는 PR118의 상태와 아래 병합 기록을 따른다.

- 요청: 00_request.md, 참조 데이터: 01_contract.md, 제작 접근: 02_image.md.
- 전용 작업 폴더: /Users/jdh/.codex/worktrees/combat-character-references/ForestArena.
- 브랜치: codex/combat-character-references. 시작 커밋: 360c6982c39746cecb11c3b46ebad363e7836aa5.
- 제작·검증 커밋: b8f8dcb4579e443ac66fe1fd329993750631adce. PR: https://github.com/Dev-DHJang/ForestArena/pull/118 (base develop). 최초에는 이미지 채택 승인 대기 draft로 보존했다.
- 네 캐릭터별 combat/front/side/rear 총16장을 제작했다. 최종 배치본은02_candidates/, 비교판은03_review/에 있다. 네 세트 모두 독립 시각 QA pass이며 qa.json과03_qa_r03.md에 실제 해시·관찰·한계를 기록했다.
- 콘텐츠 문서·이미지/애니메이션/QA 스킬과 대표 이미지 구조 검사 도구를 추가했다. 참조의 승인·원본·출처·해시와 몸 크기를 유지하며 생성 입력에 직접 첨부하도록 했다.
- 원본 PNG·실제 생성 프롬프트는 01_sources/에 남긴다. 초기 비율 불일치 시안은 r01/에 보존하고 정면 구성 모델을 먼저 맞추는 접근으로 변경했다.
- 사용자가 "채택한다."라고 명시해06_approvals/의 캐릭터별 승인 JSON에 실제 발언과16장 대상 해시를 기록했다. assets/character/<id>/reference/v01/에 승인 PNG4장과 reference.json을 각각 등록했다. PNG는 검토본과 바이트가 같고 기존130개 manifest 항목·콘셉트·외형 계약·CharacterData·전투·기존 모션·런타임 표시 배율은 유지했다.
- generation-index.json은 선택 원본·실제 프롬프트·실제 첨부 이미지의 경로/해시를 기록한다. 자현front-r02의 입력은 두 파생 이미지이며 승인 콘셉트 직접 첨부라고 확대 기록하지 않는다. 최종 QA는 승인 콘셉트와 직접 대조했다.
- 05_registration-plan.json은 승인 후 registered로 전환했고16개 motion-reference ID·경로·출처·권리 항목을 manifest에 추가했다. registration-result.json에 등록 결과와 manifest 해시를 기록했다. generation-index.json에도 정식 등록 경로와 해시를 연결했다. Android 실기기는 수행하지 않았다.
- 새 reference/4폴더에만 .gdignore를 두어 제작 참조가 Godot 가져오기 대상이 되지 않도록 했다. Python·이미지 생성의 파일 참조는 유지한다. 게임은 animation-runtime만 읽으며 이번 참조를 표시하지 않는다. 실제 APK의 용량·패키지 멤버 검증을 수행했다고 주장하지 않는다.

## 검증 기록

- python3 tools/forest_arena/test_combat_reference.py: 8개 PASS.
- skill-creator quick_validate.py: image-design, 2d-animation, qa PASS.
- ./scripts/verify.sh --list: 변경41개에 관련 검사28개 선택(생성 중간 시점).
- ./scripts/verify.sh --full: PASS, 전체91항목 완료(가져오기1회+검사90개),538.5초. build/verification/20261029-173800-3bf8f86e/result.json. 전투·UI·네트워크·리소스·하네스·신규검사 포함. 실행 코드의 미커밋 변경을 포함한 작업 폴더를 검사했다.
- 채택·정식 등록 뒤 ./scripts/verify.sh --full: PASS, 전체91항목 완료(가져오기1회+검사90개),526.7초. build/verification/20261029-181135-5ad4b9cb/result.json. 실제 등록표 통합 검사를 포함한9개 참조 검사도 포함됐다.
- 제작용 .gdignore 추가 뒤 fresh Godot headless editor scan·리소스 검사와 새 import sidecar 미생성 확인: PASS. build/verification/20261029-reference-production-exclusion/result.json. 원본 PNG16장은 파일로 읽을 수 있고 import sidecar는0개다. APK 패키지 멤버·용량 검사는 수행하지 않았다.
- 등록 후 독립 QA:03_qa_r04.md PASS. 검토 당시의 HEAD 후보/현재 후보/정식16장 바이트와 이전 QA·사용자 승인 해시 일치, 기존130개 manifest 항목 및 게임 연결 보존을 확인했다.
- 전체 검사 뒤 설명·용어 보완은 docs 분야 검사로 확인했다. 상세 보고서는 build/verification/에 있다.
- 선택16장 원본·프롬프트·실제 입력 해시와 등록 제안의 ID 충돌·대상 미등록 확인: PASS.
- 승인 전에는 --require-approved가4세트 모두 예상대로 거부됐다. 사용자 채택 승인 뒤에는 후보/정식4세트 모두 승인 필수 검사 PASS이며 원본·검토본·정식 PNG 해시가 같다.
- 이름 있는 수동 재검사: 대표 이미지 다각도 비교,128px·좌우 반전 식별,기준점 표시 비교는 독립 QA pass. 승인 참조 첨부 확인은 실제 입력의 이력·해시 연결과 정식 세트의 승인·QA·PNG 경로 연결을 확인했다. 실제 등록표→참조 세트→PNG→승인/QA 통합 검사 추가 후9개 PASS.
- 로컬 브라우저 자동 사용은 Work 설정에서 비활성화되어 화면 자동 조작 검증을 수행하지 않았다. 정지 PNG16장과 비교판은 직접 확인했다. 실제 Android·모션 재생 검사는 이번 범위가 아니다.

## 후속

후속 모션은 docs/content/combat-character-references.md에 연결한 정식 reference.json을 승인 필수 모드로 검사하고 combat와 필요한 각도를 직접 첨부한다. 기존 모션 재생성이나 게임 배율 변경은 이번 범위에 포함하지 않는다. PR118을 develop에 통합하며 롤백은 해당 병합 커밋을 revert한다. 병합 뒤 확인한 SHA는 아래 종료 증적으로 남긴다.
