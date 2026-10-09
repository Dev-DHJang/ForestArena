# 확정 음원 적용 마무리

사용자의 최종 9개 선택을 실제 게임에 적용했다. 로비·전투·점프·강한 타격·묘령 위 특수기는 v01을 유지하고, 버튼·약한 타격·가드 파괴·자현 필살기는 v02 r03 원본 PCM을 복사해 같은 논리 ID에 연결했다. 음악은 기존 80/90초 반복곡이다. 다른 38개와 기존 이벤트·버스·음량·동시 재생·중단 복귀 정책은 유지했다.

## 확인

- `apply_approved_audio_v02.py`: 반복 적용 뒤 manifest와 실행 PCM 확인값이 동일하다. 선택·원본·시안·실행 파일·출처·승인 범위는 assets/audio/v02-selected/manifest.json에 기록했다.
- `verify_audio_v02_selected.py --baseline-ref 8d0591d`: 네 PCM 복사, 47개 논리 ID, 최종 버전 맵, v01 원본·실행 파일 전체 보존, registry 전체에서 네 경로만 변경, 재생 정책 보존 PASS. 독립 QA도 별도로 수행했다.
- `verify_audio_v02_preview.py --selection-baseline-ref 8d0591d`: HTTP·9개 확정 5A/4B·기존 비교 WAV/MIDI/악보 보존·실제 음량·신호·출처 PASS, 종료 코드 0. 원본 비교 컬렉션의 모든 A/B가 승인된 것으로 확대하지 않는다.
- Godot 가져오기: 종료 코드 0. 새 네 효과음은 반복 없음·음량 정규화 없음의 WAV 설정으로 가져왔다.
- `verify_godot_resources.py --project-root .`: 397개 논리 자산, 품질별 24개 PASS.
- `./scripts/verify.sh`: 종료 코드 0, 전체 PASS. 새 선택 검사를 기본 오디오 검사에 포함했다. PHASE6_AUDIO_CONTRACT와 AUDIO_APP_FLOW는 실제 게임의 논리 ID 로드·재생과 앱 흐름을 통과했다. 기존 일부 비오디오 테스트의 종료 자원 경고는 남아 있어 전체 무경고로 표현하지 않는다.
- `./scripts/verify-docs.sh`, `git diff --check`: PASS. 독립 QA는 03_qa_r01.md에 기록한다.

선택 아홉 개는 사용자 승인 완료다. 실제 Android 출력·이어폰 전환·중단 복귀 청취와 8인전 믹스는 후속 미확인이다. 전부 47개를 v02로 재제작한 것으로 기록하지 않는다. 사용자 원래 작업 폴더는 수정하지 않았다.

## 버전 관리

기준 origin/develop: 8d0591d2c929fedbd95c4b8b40740e877bf379b5.
작업 브랜치: codex/audio-v02-approved.
구현 커밋: 5ed68ae65cbe5e7f274ba2e1e5bd73c740b37e91.
구현 PR: https://github.com/Dev-DHJang/ForestArena/pull/84.
전체 검사와 독립 QA 뒤 develop 병합: a9f5b0bfa270e1a91072f3158a64fdc4b50b9380.
2026-10-09 GitHub 상태 MERGED 및 원격 develop 커밋을 확인했다. 마무리 기록은 별도 문서 PR로 보존한다.
자동 병합 검토의 최초 권한 거절은 사용자 AGENTS가 지정한 team-spec 74행의 명시적 develop 병합 범위, 기본 브랜치 main·develop 보호 없음의 읽기 증거를 확인한 뒤 같은 작업의 재검토 승인으로 해결했다. 다른 병합 방법이나 우회는 사용하지 않았다.
롤백은 이번 구현 병합을 `git revert -m 1 a9f5b0bfa270e1a91072f3158a64fdc4b50b9380`로 되돌리는 별도 PR로 수행한다. v01 원본과 실행 파일은 그대로 보존했다.
