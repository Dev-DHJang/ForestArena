# Phase 5 Recovery R2 요청

- 기존 dirty Phase 5 작업 트리를 수정하거나 삭제하지 않고 `561c27d`에서 깨끗한 `feature/phase-5-job-growth-r2`를 시작한다.
- 차지 제거와 Phase 4 field 9/10 회귀를 먼저 복구한 뒤 세 stage 1과 여섯 stage 2 분기의 modifier·patch·실제 passive·cancel을 데이터 기반으로 완성한다.
- 개발 런처, HUD snapshot, JSONL v2와 개발 전용 10분 프레임 측정을 추가한다.
- 영속 XP·해금·경제·저장은 추가하지 않는다. Galaxy S23 Ultra 전체 매트릭스와 독립 QA 전 Phase 3–5는 blocked다.
