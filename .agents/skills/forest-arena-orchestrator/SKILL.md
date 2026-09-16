---
name: forest-arena-orchestrator
description: 여러 전문 영역·공용 계약·Phase 경계를 넘는 Forest Arena 작업과 원격 통합을 조율한다.
---

# Forest Arena 오케스트레이터

## 사용 시점

- 둘 이상의 생산 역할, 공용 계약, Phase 변경 또는 릴리스 통합이 필요한 요청에 사용한다.
- 한 역할이 안전하게 완료할 수 있는 좁은 작업에는 사용하지 않는다.

## 필수 입력

- 원 요청, README.md의 문서 우선순위, 현재 Phase와 관련 ADR.
- docs/operations/harness/team-spec.md와 기존 _workspace/<topic>/ 증적.

## 작업 흐름

1. 제품 문서와 DECISIONS.md를 대조해 미정 규칙을 찾는다.
2. 최소 역할만 선택하고 경로·소비자·검증 환경을 분리한다.
3. 00_request.md를 만들고 공용 계약 변경이면 contracts의 01_contract.md를 선행한다.
4. 독립 작업만 병렬화하고 한 소유자가 최종 통합한다.
5. qa 결과의 fix 또는 redo를 최대 두 회차 처리한다.
6. 구현·수정·완료 요청이면 최신 `origin/develop`에서 작업 브랜치를 만들고, 관련 변경만 commit·push·PR·QA 뒤 `develop` 병합까지 수행한다.
7. `04_closeout.md`에 결과, 검증, 미확인, PR·병합 SHA, 롤백과 다음 작업을 기록한다.

`main` 승격, `release/*`·`hotfix/*`, 강제 push, 이력 재작성, 원격 브랜치 삭제, 계정·권한·비밀정보 변경은 자동 범위가 아니다. 인증·보호 규칙·충돌과 실행 플랫폼의 보안 확인은 우회하지 않는다.

## 산출물과 검증

- 필요 시 `_workspace/<topic>/02_orchestrator.md`와 통합된 역할별 산출물.
- 모든 소비자가 같은 ID·상태·이벤트·Phase 의미를 쓰고 필수 기준이 pass인지 확인한다.
