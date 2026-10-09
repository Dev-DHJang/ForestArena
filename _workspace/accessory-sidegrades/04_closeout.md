# 장신구 설정 변경 마무리

추가 피해・반사・부활을 제거하고 공격 목록 변경과 작은 장단점 옵션을 실제 Resource에 연결했다. 기존 ID・보유・선택을 유지한다. 재화/결제는 미구현 그대로다.

## 검증

- ./scripts/verify.sh: 종료 0, Forest Arena verification passed. 실제 LAN・온라인 계약・전투・저장・오디오・문서・하네스 포함.
- ACCESSORY_POLICY・LOCAL_ACCESSORY_PLAY・COMBAT_OVERHAUL_CONTRACT: PASS. 금지 정의 거부, 실제 앱 24조합・피해・최종 stock・재대전 검증.
- 리소스: 397개 논리 자산, 24개 품질 변형 PASS. verify-docs・verify-harness・git diff --check PASS.
- 별도 QA r01: 구현 요구 한정 pass, 필수 수정 없음.
- 기존 게임 검사에 ObjectDB/Resource 정리 경고가 남지만 종료 0이다. 새 장신구 동작 실패로 기록하지 않는다.
- Android 실기기와 사람의 밸런스 검증은 수행하지 않았으며 공정성 통과로 표시하지 않는다.

## 통합

브랜치 codex/accessory-sidegrades, 기준 develop 3b9e361. PR・develop 병합 결과는 확인 뒤 기록한다. 기존 캐릭터・UI 작업은 별도 작업 폴더로 보존한다.

롤백: 작업 커밋 revert. DB・기기 저장・보유를 초기화하지 않는다.
