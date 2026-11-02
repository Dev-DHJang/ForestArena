# 수정 시안 등록 절차

검토 범위는 요요4종과 나비 idle의 몸 위치 보정1종이다. 기존 PNG와 시간을 보존하는 idle 보정도 모션별 사용자 채택 대상이다. QA pass는 사용자 채택을 대신하지 않는다.

- `candidate-catalog.json` / `candidate-scope.json`: 새5종의 정확한 원본·배치·시간·몸/손 기준점.
- `review-r05/motion-review.json`: 최종 참조 메타데이터를 고정한 새 독립 검토. `review-r03`은 r02 과거 시안이고 `review-r04`는 참조 정리 전의 미확인 기록이므로 새 등록에 사용하지 않는다.
- `registration-targets-r03.json`: 기존 idle의 논리 ID·SpriteFrames 소비자 경로 유지, 새 버전 PNG 경로. 기존 PNG 덮어쓰기 없음.
- 표준 등록기 `tools/forest_arena/register_motion_candidates.py` 사용. 작업용 `register_approved_motions.py`도 이 등록기를 호출한다.

독립 QA 통과 뒤 정확한 scope SHA를 지정한 읽기 전용 계획을 생성한다. 기본 실행에는 게임 파일 쓰기가 없다. 결과의 plan_sha256와 모션별 PNG/SpriteFrames 해시를 실제 사용자 채택 발언에 연결한 `user-motion-approval-r03.json`이 있어야만 `--install --backup-dir _workspace/pebble-yoyo/registration-backup-r03`을 사용할 수 있다. 승인 발언이나 승인 날짜를 미리 만들지 않는다.

등록 후에는 실제 등록된 게임 모션의 import·관련 검사와 최종 `./scripts/verify.sh --full`을 수행한다. 최종 검사를 통과하고 최신 독립 검토·승인·등록 증거가 연결된 뒤 PR120을 ready로 바꾸고 develop에 병합한다. 현재 Android 실기기 미검증 상태를 유지한다.
