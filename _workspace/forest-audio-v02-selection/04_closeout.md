# 청취 선택 마무리

로비·전투 음악, 점프와 묘령 위 특수기를 A·최초 v01로 선택했다. 비교 화면의 ‘이전 버전’을 기준으로 사용자 선호를 해석하고 네 항목의 선호 확인을 기록했다. 묘령의 다른 기술까지 확대하지 않는다.

다른 다섯 항목은 B·r03 현재 후보로 유지하고 ‘확인 전’을 표시했다. 전체 청취 승인과 게임 연결은 false다. 화면에는 네 A의 선택 표시와 나머지 B의 후보 표시, 같은 조합의 manifest 기록을 제공한다. 기존 A/B 재생과 위치 전환을 유지한다.

## 확인

- `generate_audio_v02_preview.py --skip-music`: 음악 렌더링을 재사용해 비교 정보와 선택 기록을 갱신했다. 새 작곡이나 새 음악 렌더링으로 기록하지 않는다.
- `verify_audio_v02_preview.py --baseline-ref 340057f --selection-baseline-ref 340057f`: 종료 코드 0, HTTP·9쌍 실제 음량·선택 정보·기존 게임 보존 PASS.
- 49개 WAV/MIDI/악보 JSON 전체를 Git 340057f의 실제 바이트와 비교해 모두 동일함을 독립 QA도 확인했다.
- `selection-browser-playback`: 화면의 선택된 재생기 9개의 실제 src가 네 A/다섯 B와 일치한다. 로비 A 60초·묘령 위 특수기 A 0.65초의 정상 재생과 단독 재생을 확인했다.
- `./scripts/verify.sh`: 종료 코드 0, 전체 PASS. 기존 일부 Godot 테스트 종료 자원 경고는 남아 있어 전체 무경고로 기록하지 않는다.
- `./scripts/verify-docs.sh`, `git diff --check`: PASS. 독립 QA는 03_qa_r01.md에 기록한다.

사람의 선호 확인은 요청한 네 항목에 한정한다. 나머지 후보·전체 47개 교체·실제 Android 청취는 승인 또는 검증 완료로 확대하지 않는다. 실제 게임은 기존 v01 음원을 사용한다. 사용자 원래 작업 폴더는 수정하지 않았다.

## 버전 관리

기준 origin/develop: 340057fadfcd01be01e614850bf87eb0b1c36f9e.
작업 브랜치: codex/audio-v02-selection.
구현 PR·병합 커밋은 병합 뒤 마무리 문서 PR에 기록한다.
롤백은 이번 구현 병합을 `git revert -m 1 <merge-sha>`로 되돌리는 별도 PR로 수행한다. 선택 전 r03은 131353aafa36ae65d4067f1ca4b627a2ccc871e7에 보존한다.
