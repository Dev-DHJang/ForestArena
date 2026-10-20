# 승인 전 모션 후보 검토 도구

## 현재 상태

후보 목록(catalog)과 명시한 검토 범위(scope)를 기존 도구에 추가했다. 실제 원화 후보는 조율 역할이 별도로 생성한다. 이 도구 작업은 원화·runtime PNG·manifest·전투/UI 코드를 변경하지 않는다. 샘플 JSON은 아직 존재하지 않는 후보 경로를 가리키는 사용 예시이며, 후보나 QA 통과 결과가 아니다.

- `candidate-catalog.example.json`: 기대 행위와 16프레임 후보 PNG·SpriteFrames·FPS·반복 여부·공격 데이터 근거를 함께 지정한다.
- `candidate-scope.example.json`: 검토할 캐릭터/모션을 하나씩 열거하고 원본 catalog 바이트의 SHA256을 고정한다.
- `candidate-scope.example.sha256`: scope 원본 바이트의 외부 비교값 예시다. 실제 검토에는 별도 최종 catalog/scope를 확정하고 그 SHA256을 기록한다.

## 후보 형식과 파일 경계

- 후보 catalog는 schema_version=1, kind=`motion-candidates`, approval_status=`pending`, assets의 type=`animation-candidate`다. catalog와 scope의 대상 집합은 정확히 같아야 한다. 일부만 검토하려면 그 일부의 별도 catalog/scope를 만든다. 전체 runtime 검사는 옵션 없이 기존처럼 전체 manifest를 검사한다.
- 대상 캐릭터는 기존 manifest에 있는 캐릭터이고, 모션 ID는 소문자 영문·숫자·밑줄·하이픈이다. 기대 행위와 근거 파일을 반드시 지정한다. 새 기술 안무는 샘플 이름으로 확정하지 않고 승인 요청·실제 AttackData와 대조한다.
- 새 후보 PNG와 SpriteFrames, catalog/scope/검토 출력은 프로젝트 `_workspace/` 안에 둔다. 기존 승인 모션은 `type=animation-runtime`, `reuse_approved_runtime=true`를 명시하면 등록된 원래 runtime 경로를 그대로 검토한다. 이때 PNG/tres/FPS/반복 여부는 manifest 항목과 정확히 같아야 하며 새 후보처럼 복사할 필요가 없다. 절대 자산 경로·상위 폴더 이동·프로젝트 밖 심볼릭 링크·중복 자산/모션은 거부한다.
- SpriteFrames는 그 PNG만 참조하는 SpriteFrames 자원이어야 한다. 실제 Godot 로더가 단일 모션·16 AtlasTexture 프레임·128px 순서·FPS·반복·프레임 길이를 확인한다. 스크립트와 다른 이미지 참조는 허용하지 않는다.
- `_workspace/.gdignore`를 유지한다. 검토 프로세스에서만 PNG를 메모리 텍스처로 열고 캐시 경로를 연결해 실제 `.tres`를 읽는다. 에디터 import나 게임용 자산 등록을 하지 않는다.
- 승인 전 후보가 manifest 또는 실제 scripts/scenes/assets/리소스 목록에 연결돼 있으면 거부한다. PNG/SpriteFrames를 다른 runtime 경로로 복사해 manifest에 올린 경우도 파일 해시로 거부한다.

## 실행

프로젝트 루트에서 실행한다. catalog/scope는 확정 후 바꾸지 않는다. 원화·공격 데이터·표현 코드가 바뀌면 새 디렉터리에서 새 검토를 만든다. `--scope-sha256`에는 범위 확정 때 기록한 원본 SHA256을 직접 넣는다.

```sh
godot --headless --path . --script res://tools/forest_arena/motion_review_timeline.gd -- --output /absolute/project/_workspace/two-fighter-combat-v2/review-v01/timeline.json --catalog res://_workspace/two-fighter-combat-v2/candidate-catalog.json --scope res://_workspace/two-fighter-combat-v2/candidate-scope.json --scope-sha256 ORIGINAL_SCOPE_SHA256
python3 tools/forest_arena/review_motion_actions.py prepare --project-root . --timeline _workspace/two-fighter-combat-v2/review-v01/timeline.json --output _workspace/two-fighter-combat-v2/review-v01/materials --catalog _workspace/two-fighter-combat-v2/candidate-catalog.json --scope _workspace/two-fighter-combat-v2/candidate-scope.json --scope-sha256 ORIGINAL_SCOPE_SHA256
python3 tools/forest_arena/review_motion_actions.py validate --project-root . --review _workspace/two-fighter-combat-v2/review-v01/materials/motion-review.json --catalog _workspace/two-fighter-combat-v2/candidate-catalog.json --scope _workspace/two-fighter-combat-v2/candidate-scope.json --scope-sha256 ORIGINAL_SCOPE_SHA256 --require-pass
```

출력의 상위 디렉터리는 먼저 만들고 Godot 실행을 시작한다. 도구는 scope/catalog/PNG/tres/실제 CharacterData·MoveSet·AttackData/표현·전투 코드/근거 파일의 해시를 고정한다. scope와 catalog 옵션 중 하나만 쓰거나 후보 검토를 옵션 없는 전체 검사처럼 검증하면 실패한다.

## 검토 자료와 판정

- 전체 16프레임 비교판과 원본 시트를 보존한다. `character_movesets` 맵으로 캐릭터별 실제 검토 MoveSet을 명시하고 `attack_sources`에도 같은 자원을 고정한다. 후보 모드의 profile과 공격 변형은 이 MoveSet에서 읽으며 구형 기본 기술로 대신하지 않는다. HTML은 실제 표현 코드의 60Hz 프레임/공격 단계와 원화 16프레임/FPS를 선택해 비교한다. 정상 1배·느린 0.25배·좌우 반전·작은 표시·정지가 가능하다.
- 실제 표현 코드와 AttackData 시간으로 기록한 재생이다. `fighter_attack_effects.gd`도 기본/후보 해시에 고정한다. HTML의 시트 재생은 절차적으로 그리는 리본/클로 효과를 직접 그리지 않으므로, 효과까지 포함한 행위 판정에는 조율 역할의 별도 Godot 실제 화면 검토 자료를 함께 본다. 고정 상태/점프 시험 조건은 전체 실제 경기 녹화와 구분해 설명한다. 정적 전체 원화 FPS를 게임 타이밍으로 대신하지 않는다.
- prepare는 상태 `blocked`, 모든 검토 항목 false, 검토자 공란으로 만든다. 독립 QA가 전체 자료를 직접 보고 reviewer/reviewer_role=`qa`, 모션별 관찰·문제 프레임/시간과 검사 항목을 기록한다. 기록 검사만으로 그림의 행위가 맞다고 보장하지 않는다.
- validate는 자료 HTML·timeline·보드·원본 시트·근거 파일 해시를 다시 검사한다. 해시 변경·누락·중복·범위 변경·관찰/검사 없는 pass를 거부한다. require-pass는 한 모션이라도 blocked/fix/redo면 실패한다.
- 독립 QA 통과도 사용자 승인이 아니다. 후보 검토의 approval_status는 계속 pending이고, 모션별 사용자 승인 뒤에만 별도 절차로 runtime/manifest에 등록한다.

## 자동 검사

- `python3 tools/forest_arena/test_motion_action_review.py`: 기존 25개 + 후보 범위/자료 23개 + 실제 Godot 검사 5개, 총 53개 PASS (최종 재개 실행). 로그 `/tmp/fa-motion-e2e-tests2.log`.
- 후보의 scope 원본 바이트 변경·catalog 변경·대상 누락/중복/unknown·경로 이탈·승인 전 runtime 노출·AttackData/표현 코드/PNG/tres/자료 변경·근거 없는 pass를 검사했다.
- 실제 Godot 검사에서 `.gdignore` 아래 PNG의 import 없이 `.tres` 읽기와 프레임 순서·FPS·길이 변경 거부를 확인했다. 임시 단색 PNG는 자동 검사 전용이고 후보 원화나 사용자 검토 자료로 취급하지 않는다.
- 전투 코드 작성 중 보였던 컴파일 오류는 생산자 완료 후 사라졌다. 기본 전체 manifest의 120모션 timeline 실행 PASS(`/tmp/fa-motion-default-new.log`). 후보 목록에 명시한 새 두 MoveSet으로 새 자현 강공격 `[12,5,20]`, 자현 목도리 특수 `[12,60,24]`, 나비 특수 `[10,24,24]`가 기록되는 끝부터 끝까지 검사도 PASS했다. 구형 base_move_set을 잘못 읽는 문제를 수정하고 회귀 검사를 추가했다.


## Android 자동 검사 도구 전달

- 모바일 스킬을 읽고 `android_fleet.py`와 해당 Python 자동 검사를 protocol 3 새 제품 규칙에 맞췄다. 기본 호스트 코드는 FAH3, 초대 코드는 FA3이며 protocol 2/3은 같은 인증 API·닉네임 과정과 초대 코드의 방 번호 위치를 사용한다. protocol 1은 기존 비인증 과정을 보존한다.
- protocol 3의 상점·실제 선택·반복 대전 조합은 자현/나비와 장신구 미장착 두 개다. 이미 저장된 다른 캐릭터·장신구 보유는 지우지 않고, 현재 전투의 통과 범위에 섞지 않는다. 기기 4대를 골라도 각 기기에 빈 조합 목록을 주지 않는다.
- 실제 준비 UI의 비활성 캐릭터·장신구 선택 노출과 실제 참가자 모두의 활성 캐릭터/미장착을 확인한다. 실제 프로필에는 기본 대시·차지·필살기와 장신구 능력치/교체/효과가 없어야 한다.
- 입력은 방향패드와 점프·약·강·특수 네 버튼의 누름/해제와 실제 전투 변화를 검사한다. 제거된 회피·필살기 검사를 실행하거나 통과로 기록하지 않는다. `--current-policy`의 이전 장신구 검사도 protocol 3에서는 실행하지 않는다.
- protocol 1/2는 명시적으로 선택할 때 이전 28조합과 장신구/회피/필살기 검사를 유지한다. 요약은 사용한 전투 정책 ID와 그 정책의 조합 수를 기록하며 두 정책의 결과를 합쳐 기기 통과로 승격하지 않는다.
- 단위 검사는 실제 ADB/기기 연결 없이 실행하는 도구 동작 검사다. 실제 Android 실행/패키지/접근성 결과로 기록하지 않는다.

- 모바일 도구 최종 검사: `python3 tools/forest_arena/test_android_fleet.py` 146개 PASS, 기존 134개 보존 + 새 정책 12개. 실제 구매/선택/입력 루프가 새 정책만 실행하는지, protocol 1/2 코드와 인증 흐름 보존, protocol 3 room 필드·네 버튼·새 프로필, 빈 작업 분배 방지·정책별 요약을 확인했다. 로그 `/tmp/fa-fleet-v3-tests-final.log`. 실제 연결 기기를 실행한 결과가 아니다.
- 필수 검토 근거가 바뀌는 것을 막기 위해 후보 catalog는 `character_movesets`에 범위의 모든 캐릭터를 빠짐없이 지정해야 한다. 이 자원은 `attack_sources`에도 있어야 한다. 예제도 새 자현 MoveSet으로 갱신하고 scope의 catalog SHA256과 외부 scope SHA256을 다시 고정했다.
