# 진행·인계 기록

- 브랜치: feature/local-ai-playable. 시작점 origin/develop fada2ac.
- 작업 폴더: ForestArena-local-ai. 원래 ForestTales의 미커밋 UI 변경은 보존했다.
- 구매·저장·앱 흐름·AI·1080/540 경기장·확장 터치·승인 모션 연결을 구현했다.
- 코드, Android export와 에뮬레이터 앱 흐름 검사는 통과했다. 상세 범위는 03_qa_r01.md와 03_qa_r02.md.
- 전체 목표는 미완료: 신규 전투 모션 제작·검토·등록과 실제 기기 검사가 남았다. Phase 6 전체 완료를 선언하지 않는다.
- 모션 r01–r03은 수정 이력이고 r04는 사용자 검토 시안이다. runtime 자산이나 기존 manifest는 변경하지 않았다.
- 롤백: 이번 브랜치의 통합 커밋을 되돌리면 기존 개발 장면 시작으로 돌아간다. 새 로컬 보유 파일은 user://local_player.json과 .bak이며 이전 버전은 이 파일을 읽지 않는다. 사용자 파일을 자동 삭제하지 않는다.
