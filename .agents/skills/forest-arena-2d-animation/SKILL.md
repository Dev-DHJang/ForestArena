---
name: forest-arena-2d-animation
description: Forest Arena 프레임 애니메이션·스프라이트 시트·SpriteFrames와 승인 캐릭터 모션 패키지를 제작한다.
---

# Forest Arena 2D 애니메이션

## 사용 시점

- 캐릭터·직업·장신구의 프레임, 아틀라스, SpriteFrames와 시각 래퍼에 사용한다.
- 승인 콘셉트의 표준 idle·jump·run 16프레임 패키지와 모션별 사용자 승인 게이트를 소유한다.
- Hitbox/Hurtbox, 공격 단계 시간, 플랫폼 충돌과 승패는 소유하지 않는다.

## 필수 입력

- 현재 Phase, docs/content/art-and-audio.md, 턴어라운드·키 포즈와 전투 의미 상태.
- 승인 캐릭터 프레임이면 `docs/contracts/character-appearance-v01.json`의 해당 외형 항목.
- 파일·메모리 예산 후보, 에셋 권리 상태와 소비 경로.

## 작업 흐름

1. 승인 캐릭터 모션은 manifest, 승인 콘셉트 PNG와 외형 계약을 확인하고 `_workspace/character-motion-<character-id>/`에 시안과 검토를 남긴다.
2. idle은 8 FPS 루프, run은 12 FPS 루프, jump는 단발 기본값으로 각각 16프레임·128×128 셀·2048×128 시트를 만든다.
3. 모션별 사용자 명시 승인 전에는 런타임 경로·manifest에 쓰지 않고, 승인되지 않은 모션은 런타임 파일을 생성하지 않는다.
4. 승인 뒤에만 `assets/character/<character-id>/animation/runtime/<motion>_16f.png`와 `<motion>.tres`를 등록하고 manifest에 생성 방식·권리·해시·소비 경로를 갱신한다.
5. 프레임 순서, pivot, 방향 전환, 루프, alpha, 잘림과 외형 계약의 필수·각도 한정·금지 요소를 검증한다. 애니메이션은 AttackData 타이밍을 표현하며 판정을 결정하지 않는다.
6. 공급자별 경로를 공용 전투 코드에 노출하지 않고 최대 줌아웃 실루엣과 Android 메모리·draw call 영향을 측정한다.

## 산출물과 검증

- 필요 시 `_workspace/<topic>/02_2d_animation.md`, 원본·런타임 경로, 매핑과 권리 기록.
- import, 프레임 누락, 잘림, 방향, 교체 가능성, SpriteFrames 참조, manifest 기록과 판정 분리를 검사한다.
