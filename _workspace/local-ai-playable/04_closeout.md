# 진행·인계 기록

- 브랜치: feature/local-ai-playable. 시작점 origin/develop fada2ac.
- 작업 폴더: ForestArena-local-ai. 원래 ForestTales의 미커밋 UI 변경은 보존했다.
- 구현 커밋: `7024353`. 원격 `feature/local-ai-playable`에 push했다.
- 검토 PR: https://github.com/Dev-DHJang/ForestArena/pull/38 (Draft, 대상 develop). 필수 미완료 항목 때문에 병합하지 않았으며 병합 SHA는 없다.
- 구매·저장·앱 흐름·AI·1080/540 경기장·확장 터치·승인 모션 연결을 구현했다.
- 코드, Android export와 에뮬레이터 앱 흐름 검사는 통과했다. 상세 범위는 03_qa_r01.md와 03_qa_r02.md.
- 전체 목표는 미완료: 신규 전투 모션 제작·검토·등록과 실제 기기 검사가 남았다. Phase 6 전체 완료를 선언하지 않는다.
- 모션 r01–r03은 수정 이력이며 나비 약공격 1단 r04는 2026-09-26 사용자 승인을 받았다. 내장 이미지 도구의 투명화 결과에 잡픽셀·흰 테두리가 남아 품질 검사 실패로 등록을 보류했다. runtime 자산이나 기존 manifest는 변경하지 않았다. 로컬 이미지 처리 방식 확인 뒤 투명화·규격 검사를 이어간다.
- 추가 검증: 16개 전체 캐릭터 조합 경기 종료와 한 경기 전체 tick hash 재현 통과. 상세 범위는 03_qa_r03.md.
- 후속 장신구 검사에서 부활 복귀 HP 덮어쓰기와 이전 경기 지연 결과가 재대전에 적용되는 문제를 발견·수정했다. 4캐릭터×6장신구 실제 적중 효과·복귀·재대전 초기화 전용 검사와 독립 QA가 통과했다. UI 구매 터치나 24조합 AI 완주를 검증했다는 뜻은 아니다. 상세 범위는 03_qa_r04.md 및 03_qa_accessories_independent_r02.md.
- 롤백: 이번 브랜치의 통합 커밋을 되돌리면 기존 개발 장면 시작으로 돌아간다. 새 로컬 보유 파일은 user://local_player.json과 .bak이며 이전 버전은 이 파일을 읽지 않는다. 사용자 파일을 자동 삭제하지 않는다.
