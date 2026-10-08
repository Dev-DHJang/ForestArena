# 기본 게임 DB 연동 완료 기록

## 구현

기본 게임에 기기 저장·로컬 DB 저장 모드를 연결했다. 게스트 로그인과 프로필 API를 통해 첫 지급·0원 구매·선택·접근성 설정을 실제 PostgreSQL에 저장하고 재실행 시 복원한다.

DB 확인 후 화면에 반영하며 동일 요청 재시도와 변경 번호 검사로 중복·동시 변경을 처리한다. DB가 비었을 때만 기기 기록을 읽기 전용으로 이전한다. 기존 DB·기기 파일·사용자 이미지 작업을 보존했다.

## 검증

- 전체 ./scripts/verify.sh: PASS. 기존 전투·로드아웃·기기 저장·LAN·온라인·문서·하네스 검사 포함.
- ./scripts/verify-db-profile-runtime.sh: PASS. 실제 Godot 기본 앱의 저장·별도 프로세스 복원·SQL 대조·실패·응답 유실·토큰 복구·동시 최초 지급 포함.
- 기존 온라인 ./scripts/server-dev.sh verify-runtime: PASS 확인 후 토큰 수정 영향 범위를 재검사 중이다.
- 문서·하네스·346개 논리 자산 검사: PASS.
- 별도 QA: 1차 fix 두 건 수정 뒤 2차 pass.

## 통합

작업 브랜치: feature/local-db-profile. PR·develop 통합 결과는 완료 시 이 항목에 기록한다.

기존 GitHub CLI 인증이 없어 일반 Chrome 로그인 세션으로 PR 절차를 진행한다. 자격 증명 추출 재사용 확인은 자동 승인 검토에서 거부되어 중단했다.

## 미확인과 복구

이번 완료 기준은 Mac 실제 게임·API·PostgreSQL이다. Android 실기기 DB 연결과 운영 계정·경제·성장은 구현·통과 범위가 아니다.

롤백은 변경 커밋 revert와 기기 저장 모드 선택으로 한다. migration 0003·0004와 기존 DB 볼륨은 자동 삭제하지 않는다.
