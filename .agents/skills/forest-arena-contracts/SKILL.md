---
name: forest-arena-contracts
description: 버전이 있는 Forest Arena Resource·저장·공용 ID·로드아웃·미래 네트워크 계약을 정의한다.
---

# Forest Arena 공용 계약

## 사용 시점

- Resource 필드, 조합 순서, 저장, 공용 ID 또는 미래 메시지 경계 변경에 사용한다.
- 시각 전용 변경이나 한 컨트롤러 내부 구현에는 사용하지 않는다.

## 필수 입력

- 현재 Phase, docs/engineering/architecture.md, 관련 ADR와 모든 생산자·소비자.
- 호환성, 실패·롤백 방식과 검증 기준.

## 작업 흐름

1. 구현 전에 _workspace/<topic>/01_contract.md에 타입, 의미, 불변 조건과 소비자를 기록한다.
2. CharacterData, JobData, AccessoryData와 RuntimeCombatProfile 조합의 소스 비변경성을 보존한다.
3. 온라인 계약은 Phase 7과 accepted 네트워크 ADR 전 확정하지 않는다.
4. 호환을 깨는 변경은 마이그레이션 또는 명시적 거부·롤백을 요구한다.

## 산출물과 검증

- 01_contract.md와 계약 테스트.
- 누락 필드, 잘못된 ID, 조합 충돌, 구버전 입력과 모든 소비자 갱신을 검사한다.
