---
name: forest-arena-2d-animation
description: Forest Arena 프레임 애니메이션·스프라이트 시트·SpriteFrames와 승인 캐릭터 모션 패키지를 제작한다.
---

# Forest Arena 2D 애니메이션

## 사용 시점

- 캐릭터·직업·장신구의 프레임, 아틀라스, SpriteFrames와 시각 래퍼에 사용한다.
- 승인 콘셉트의 기본 이동·공격·특수기·피격 등 모션 패키지와 모션별 사용자 명시 승인을 소유한다.
- Hitbox/Hurtbox, 공격 단계 시간, 플랫폼 충돌과 승패는 소유하지 않는다.

## 필수 입력

- 현재 Phase, docs/content/art-and-audio.md, 턴어라운드·키 포즈와 전투 의미 상태.
- 승인 캐릭터 프레임이면 `docs/contracts/character-appearance-v01.json`의 해당 외형 항목.
- 새 모션은 `docs/content/combat-character-references.md`의 승인 대표 세트를 먼저 확인한다. `reference.json`의 승인·해시를 검증하고 기본 자세와 필요한 각도를 생성 입력에 직접 첨부한다. 사용한 세트·버전·첨부 이미지 해시를 작업 기록에 남긴다. 누락·미승인·해시 불일치는 기준 복구 전 제작을 멈춘다. 기존 승인 모션의 재생은 그대로 둔다.
- 파일·메모리 예산 후보, 에셋 권리 상태와 소비 경로.

## 작업 흐름

1. 승인 캐릭터 모션은 manifest, 승인 콘셉트 PNG와 외형 계약을 확인하고 `_workspace/character-motion-<character-id>/`에 시안과 검토를 남긴다.
2. `docs/content/motion-action-review.md`에 따라 제작 전에 기대 행위·핵심 자세·방향·공격 단계를 기록한다. 새 모션과 수정 모션은 전체 프레임·정상 속도·게임 재생 자료를 QA에 전달하고 독립 검토 뒤 사용자 승인을 요청한다.
3. 기존16프레임 자산의 idle8 FPS·run12 FPS·jump단발 기본값은 호환한다. 신규는 선언한16·24·32프레임과128×128 셀·최대16열을 사용한다. 그림 수와 단계별 표시 시간은 전투 시간을 바꾸지 않는다.
4. 모션별 사용자 명시 승인 전에는 런타임 경로·manifest에 쓰지 않고, 승인되지 않은 모션은 런타임 파일을 생성하지 않는다.
5. 승인 뒤에만 `assets/character/<character-id>/animation/runtime/<motion>_<frame_count>f.png`와 `<motion>.tres`를 등록하고 manifest에 생성 방식·권리·해시·소비 경로를 갱신한다.
6. 프레임 순서, pivot, 방향 전환, 루프, alpha, 잘림과 외형 계약의 필수·각도 한정·금지 요소를 검증한다. 애니메이션은 AttackData 타이밍을 표현하며 판정을 결정하지 않는다.
   대표 이미지와 몸·머리 비율, 얼굴·의상·색을 전체 프레임에서 비교한다. 몸 기준 공통 배율을 쓰고 귀·꼬리·리본의 외곽에 맞춰 프레임마다 크기를 바꾸지 않는다. 원화에서 128px 셀로 바꾸는 공통 배율·발 기준점은 모션 기록에 남긴다.
7. 공급자별 경로를 공용 전투 코드에 노출하지 않고 최대 줌아웃 실루엣과 Android 메모리·draw call 영향을 측정한다.

## 산출물과 검증

- 필요 시 `_workspace/<topic>/02_2d_animation.md`, 원본·런타임 경로, 매핑과 권리 기록.
- import, 프레임 누락, 잘림, 방향, 교체 가능성, SpriteFrames 참조, manifest 기록과 판정 분리를 검사한다.
