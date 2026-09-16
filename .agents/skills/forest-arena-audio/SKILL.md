---
name: forest-arena-audio
description: 교체 가능한 의미 이벤트로 Android 대응 Forest Arena 음악과 효과음을 제작·통합한다.
---

# Forest Arena 오디오

## 사용 시점

- BGM, 공격·피격·링아웃·UI SFX, 이벤트와 믹스에 사용한다.
- 전투 상태·타이밍 또는 승패 규칙 변경에는 사용하지 않는다.

## 필수 입력

- 현재 Phase, docs/content/art-and-audio.md, 장면·감정·루프와 이벤트 목록.
- 전투·UI 의미 이벤트, 동시 발음 예산 후보와 권리 조건.

## 작업 흐름

1. event, asset, bus, priority와 concurrency 계약을 작성한다.
2. 오디오는 의미 이벤트를 표현하며 전투 결과를 만들지 않는다.
3. 원본·생성 과정·라이선스·교체 규칙을 기록한다.
4. Android 중단·복귀, 출력 전환과 중복 재생을 검증한다.

## 산출물과 검증

- _workspace/<topic>/02_audio.md와 이벤트 매핑·권리 기록.
- 누락·중복, 루프 경계, 믹스와 오디오 없는 상태 이해를 검사한다.
