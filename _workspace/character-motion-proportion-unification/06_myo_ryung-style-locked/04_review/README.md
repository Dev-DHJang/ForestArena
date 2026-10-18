# 묘령 새 그림체 31종 검토

2026-10-16, 선택하신 그림체로 전체 31종 검토 이미지를 준비했다. idle·run·attack_air_heavy는 이미 승인됐고 파일을 그대로 보존했다. 나머지 28종은 개별 승인 대기다. 전체 사용자 승인이나 게임 반영 완료는 아직 아니다.

- `index.html`: 31종의 반복 GIF, 개별 투명 시트 링크와 승인 상태를 한 화면에서 본다.
- `31-motion-overview.png`: 기술별 주요 포즈를 모은 전체 비교판이다.
- `31-motion-report.json`: 31종 원본·실제 크기·alpha·배율·프레임 배치·SHA-256이다.
- `qa-pages/`: 모든 포즈를 확인할 수 있는 8개 접촉판이다.

- `style-detail-comparison.png`: 선택 원본 → 새 대기 → 새 달리기 → 새 공중 강공격 순서다. 머리 크기를 같게 맞춰 얼굴·선·명암을 비교한다.
- `style-comparison.png`: 같은 128px 셀에서 첫 포즈와 8번째 포즈를 비교한다.
- `ja-hyun-size-comparison.png`: 자현 → 선택 원본 → 새 대기 → 새 달리기 → 새 공중 강공격 순서다. 귀를 제외한 기본 자세 몸 높이와 머리 표시 크기를 확인한다.

각 폴더에는 `<state>-r01-clean.png` 4×4·16포즈 투명 시트, 128px 첫 포즈/주요 포즈, 16프레임 GIF와 눈으로 표시한 측정 위치가 있다. GIF는 검토를 위해 반복하며 실제 게임의 반복 설정을 바꾼 것은 아니다.

검토할 파일:

- `idle/idle-r01-clean.png`, `idle/idle-r01.gif`
- `run/run-r01-clean.png`, `run/run-r01.gif`
- `attack_air_heavy/attack_air_heavy-r01-clean.png`, `attack_air_heavy/attack_air_heavy-r01.gif`

첫 3종의 승인 기록은 `../approval-proof-3.json`, 당시 구조·해시 기록은 `report.json`이다. 나머지 28종의 검사와 남은 내용은 `../05_remaining/03_qa_r01.md`, 생성 프롬프트는 `../05_remaining/generation-prompts-r01.json`을 따른다. 각 배경 제거 요청과 궁극기 2포즈 수정 요청은 `../03_alpha/`에 있다. 내장 이미지 도구를 사용했다.
