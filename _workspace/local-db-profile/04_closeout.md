# 기본 게임 DB 연동 완료 기록

## 구현

기본 게임에 기기 저장·로컬 DB 저장 모드를 연결했다. 게스트 로그인과 프로필 API를 통해 첫 지급·0원 구매·선택·접근성 설정을 실제 PostgreSQL에 저장하고 재실행 시 복원한다.

DB 확인 후 화면에 반영하며 동일 요청 재시도와 변경 번호 검사로 중복·동시 변경을 처리한다. DB가 비었을 때만 기기 기록을 읽기 전용으로 이전한다. 기존 DB·기기 파일·사용자 이미지 작업을 보존했다.

## 검증

- 전체 ./scripts/verify.sh: PASS. 기존 전투·로드아웃·기기 저장·LAN·온라인·문서·하네스 검사 포함.
- ./scripts/verify-db-profile-runtime.sh: PASS. 실제 Godot 기본 앱의 저장·별도 프로세스 복원·SQL 대조·실패·응답 유실·토큰 복구·동시 최초 지급 포함.
- 기존 온라인 ./scripts/server-dev.sh verify-runtime: PASS. 토큰 수정 뒤 실제 온라인 호환 검사를 다시 통과했다.
- 문서·하네스·346개 논리 자산 검사: PASS.
- 별도 QA: 1차 fix 두 건 수정 뒤 2차 pass.

## 통합

작업 브랜치: feature/local-db-profile.

- 구현 커밋: 7f2e28a1eb95e41f7db66a193fb7e660295c5307.
- PR: https://github.com/Dev-DHJang/ForestArena/pull/64.
- develop 병합 커밋: 5f5d818834fbed3fd0554ef3da3ba56e902af5e7. PR #64 병합 완료.
- 병합 SHA를 기록하는 후속 문서 브랜치: docs/local-db-profile-closeout.

일반 Chrome 로그인 세션으로 PR을 생성했다. 계정·권한·비밀번호 설정은 변경하지 않았다.

## 미확인과 복구

이번 완료 기준은 Mac 실제 게임·API·PostgreSQL이다. Android 실기기 DB 연결과 운영 계정·경제·성장은 구현·통과 범위가 아니다.

롤백은 변경 커밋 revert와 기기 저장 모드 선택으로 한다. migration 0003·0004와 기존 DB 볼륨은 자동 삭제하지 않는다.
