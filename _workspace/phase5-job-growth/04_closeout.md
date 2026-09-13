# Recovery R2 closeout

- 구현: 차지 제거, schema migration, Phase 4 field 보존, 여섯 leaf 콘텐츠, passive/cancel runtime, 개발 UI, JSONL v2와 frame recorder.
- 자동 계약·회귀 검증: `./scripts/verify.sh`, Godot 리소스 검사와 `git diff --check` 통과.
- Android debug export: `build/android/ForestArena-debug.apk` 생성 및 APK 계약 검사 통과.
- 보존된 기존 dirty 작업 트리는 수정·삭제하지 않았다.
- R2 Galaxy S23 Ultra 30매치, renderer-level 10분 측정과 독립 QA 증적이 없으므로 Phase 3–5 상태는 `blocked`다.
