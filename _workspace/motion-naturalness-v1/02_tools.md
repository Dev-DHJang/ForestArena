# 가변 프레임 제작·검토 도구

2026-10-21. 담당: motion_tools. 승인된 PNG·manifest·전투 계산은 수정하지 않았다.

## 변경

- `motion_layout.py`에서 16·24·32프레임, 128px 셀, 최대 16열·두 줄, 행 우선 순서와 프레임별 양수 재생 시간을 검증한다. 생략하면 기존 16프레임·한 줄·시간 1.0을 그대로 사용한다.
- 단계별 그림 범위는 순서대로 전체 그림을 덮어야 한다. 점프의 상승·정점·하강·착지, 달리기 한 주기의 이동 거리, 프레임별 목도리 부착점을 검증한다. 그림 좌표와 메타데이터를 검사할 뿐 전투 수치를 바꾸지 않는다.
- 후보 SpriteFrames는 실제 Godot 로더로 PNG 연결, 행·열, 프레임 수·순서·시간을 확인한다. 마지막 줄의 사용하지 않는 셀은 투명해야 한다. 후보를 에디터로 가져오거나 런타임에 노출하지 않는다.
- 실제 표시 코드의 검토 기록은 새 공격의 구간별 그림 수가 실제 전투 틱을 넘으면 거부한다. 새 24·32프레임 공격은 명시적인 단계 범위가 필요하며, 가중 시간 때문에 실제 표시되지 않은 그림도 거부한다. 기존 승인 16프레임 재사용은 기존 시간으로 유지하고 초과 그림 수를 경고한다.
- 달리기 거리 메타데이터가 있으면 위치를 실제로 전진시키며 두 거리 주기를 기록한다. 점프 샘플은 선언된 각 단계 안에서만 재생되어야 한다. 표시 코드가 전투 상태를 바꾸지 않는 기존 검사도 유지한다.
- 검토 페이지의 전체 그림, 정상 원화 재생 시간, 게임 코드 재생, 반전·작은 표시를 가변 프레임에 맞췄다. 2행 시트의 아래 행도 올바르게 잘라 표시한다. 새 공용 도구도 자료의 해시에 포함한다.
- Godot 모션 계약 검사는 선언된 수·행열·시간을 사용한다. `visual_state_id`가 있으면 파일 이름보다 우선한다. 공격 모션도 버전이 붙은 PNG 이름을 허용한다.

## 승인 뒤 등록 경로

`register_approved_motion_batch.py`는 2026-10-03 local-AI 배치의 고정된 모션·권리 문구·16프레임을 전제로 한 과거 도구다. 이전 승인 기록의 뜻을 바꾸지 않기 위해 수정하지 않았다. 과거 119종 staging·audit·설치 도구도 이번 시안 검토 경로에서 사용하지 않는다.

대신 `register_motion_candidates.py`를 추가했다. 기본 실행은 파일을 쓰지 않는 dry-run(등록 전 검토)이다. 현재 후보의 고정 scope와 독립 QA pass가 필요하다. 별도의 targets JSON은 각 모션의 논리 ID, 최종 `.tres` 경로, 새 버전 PNG 경로와 향후 사용자 승인 기록의 위치를 명시한다. 기존 모션은 ID와 `.tres` 소비 경로가 달라지면 거부한다. 새 PNG는 `guard_24f_v02.png`와 같이 프레임 수와 버전을 포함하고 기존 파일을 덮어쓰지 않아야 한다.

명령 형태:

```sh
python3 tools/forest_arena/register_motion_candidates.py \
  --project-root . --catalog <candidate-catalog.json> \
  --scope <candidate-scope.json> --scope-sha256 <고정 scope 해시> \
  --review <motion-review.json> --targets <registration-targets.json>
```

출력 계획은 후보 PNG 해시, 후보 SpriteFrames 해시, `_workspace` PNG 참조를 최종 경로로 바꾼 SpriteFrames 해시, 최종 manifest 해시와 등록기·레이아웃 코드 해시를 포함한다. 계획의 정규화된 JSON 해시인 `plan_sha256`도 출력한다. 같은 입력이면 같은 계획이 나온다.

`--install --backup-dir <새 _workspace 백업 폴더>`를 추가하면 실제 등록을 요청한다. 이때만 별도 사용자 승인 기록을 요구한다. 기록은 `source=user`, 정확한 계획·catalog·scope·QA·targets 해시와 **각 모션별** 명시 승인, PNG/원본·최종 SpriteFrames 해시, 사용자 메시지·참조·날짜를 포함해야 한다. 누락되거나 바뀌면 첫 폴더 생성 전 거부한다. 설치 직전에 QA와 입력·출력 해시를 다시 검사하고, 기존 manifest·SpriteFrames를 백업한다. 기존 PNG는 삭제하거나 덮어쓰지 않는다.

이번 작업에서는 실제 사용자 승인 기록을 만들거나 등록을 실행하지 않았다. 자동 검사에서만 임시 프로젝트와 가상 승인 문자열을 사용했다. 시안 10종의 실제 QA와 사용자 승인 뒤에 targets와 승인 기록을 확정할 수 있다.

## 검증

- `python3 tools/forest_arena/test_motion_action_review.py`: **77개 PASS**. 기존 54개에 가변 수·2행·시간·잘못된 범위·부착점·보이지 않는 공격 그림·달리기 거리·공중 착지 금지 검사를 추가했다. 실제 Godot가 16·24·32 SpriteFrames를 읽고 후보 파일이 변하지 않는지도 확인한다. 등록 검사 9개는 16·24·32 dry-run의 무변경, 최종 참조 해시, 승인 누락·QA 대체·해시 변조·누락 모션 거부, 오래된 QA 거부, 경로·덮어쓰기 거부, 임시 프로젝트에서 기존 PNG와 ID·소비 경로 보존을 확인한다. 전체 승인 120모션의 실제 표시 기록도 생성해 모든 상태·공격 변형의 샘플과 틱 수를 검증한다.
- `godot --headless --path . --script res://tests/character_motion_contract.gd`: **PASS**.
- `godot --headless --path . --script res://tests/character_attack_motion_contract.gd`: **PASS**.
- 상세 로그는 이 폴더 `qa/tools-tests.log`, `qa/character-motion-contract.log`, `qa/character-attack-motion-contract.log`에 남겼다.

위 결과는 도구와 기록의 일관성 검사다. 새 원화가 자연스럽다는 판정이나 사용자 승인을 뜻하지 않는다. 실제 Android 확인은 실행하지 않았다.
