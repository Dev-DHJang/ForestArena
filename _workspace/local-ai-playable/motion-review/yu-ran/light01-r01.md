# 유란 약공격 1단 r01 검토 시안

## 상태

- 사용자 검토 전 시안이다. 런타임 경로와 manifest에는 등록하지 않았다.
- 기술: `yu-ran-light-01`, `attack_light_combo_01`. 준비 4 / 활성 3 / 회복 7 tick이다. 검토 그림은 판정 시점을 결정하지 않는다.
- 승인 콘셉트와 idle 시트를 각각 외형·크기 참고로 사용했다.
- 16개 자세를 4×4로 배치했다. 1–4번 준비, 5–7번 오른손바닥 짧은 찌르기, 8–16번 회수 의도다.
- 1262×1246 RGB 검토 이미지이며 정확한 런타임 셀 규격이 아니다. 승인 뒤에만 투명화·128×128 셀 정규화와 발 기준선 검사를 진행한다.
- SHA-256: `51753189243ce8df4ca51a459196280fd50bf8519685c7d3ace2a50496ff882c`.

## 시각 확인

잿빛 은발, 둥근 갈색 귀 두 개, 갈색·흰색 고리무늬 꼬리 한 개, 인간형 손발,
갈색·흰색·검정 의상과 청록 보석을 유지한다. 전진하는 손바닥과 뒤쪽 경계 손이
구분되며 두 발은 지면에 남는다. 회수 후반의 차이가 작고 배경은 거의 균일하지만
픽셀값이 완전히 한 색은 아니다. 승인 여부와 별개로 런타임 정규화가 필요하다.

## 생성 프롬프트

```text
Use case: stylized-concept.
Asset type: Forest Arena 2D animation review sprite sheet, not a runtime asset.
Primary request: Create a NEW 16-pose review sheet for Yu-Ran light combo attack 01, a fast grounded lead-hand palm jab toward the RIGHT.
Input images: Image 1 is the approved Yu-Ran identity/costume reference. Image 2 is only a scale, side-view, and sprite rendering reference; do not copy its static pose into every frame.
Scene/backdrop: exactly uniform opaque medium-dark gray #34383f.
Subject: adult female three-head-tall human-form weasel-themed fighter, ash-silver hair, exactly two round brown weasel ears with white inner tufts, exactly ONE oversized long brown-and-white ringed tail, brown/white/black fur-collar street jacket, black cropped inner layer, white fitted shorts with black straps, black fingerless gloves, brown-white-black high-top sneakers, large black bow and teal ribbon accents, readable teal diamond belt gem.
Style/medium: polished chibi game sprite animation concept consistent with the references, clean anti-aliased silhouette.
Composition/framing: exactly 16 equal cells in a square 4x4 grid, row-major, one full-body pose per cell. All face RIGHT in stable side/three-quarter view. Identical root position, foot baseline, character scale and limb length. At least 10% padding around ears, tail, hands and feet. No neighboring-cell overlap.
Motion progression: frames 1-4 settle into a wide tail-ready stance and draw the front/lead hand back; frames 5-7 execute a short fast open-palm jab at chest height to the right while rear hand guards; frames 8-16 retract smoothly to ready stance. Both feet remain planted. The huge ringed tail counterbalances naturally and stays readable as one tail. This depicts attack timing startup 4 ticks / active 3 / recovery 7 ticks, but print no numbers.
Constraints: preserve approved identity, human face/hands/feet/body, exactly two round ears and one oversized ringed tail. Make all 16 poses progressive and visibly distinct. Keep every silhouette fully inside its cell.
Avoid: animal muzzle, animal face, fur-covered limbs, paw hands, paw feet, digitigrade legs, extra ears, extra tails, copied brand/emblem, text, labels, numbers, grid lines, borders, shadows, VFX, particles, opponent, weapons, camera movement, white outline, halo, debris.
```

## 배경 정리 프롬프트

```text
Use case: precise-object-edit.
Asset type: Forest Arena animation review contact sheet.
Primary request: Clean ONLY the background and edge debris of this exact 4x4 Yu-Ran animation sheet. Preserve all 16 character poses, their order, scale, root placement, costume, face, exactly two round ears, exactly one oversized brown-white ringed tail, teal gem, hands, feet, and palm-jab progression exactly as drawn.
Scene/backdrop: replace every black, transparent, gray-white, red, yellow, and stray colored background speck between/around characters with one perfectly uniform OPAQUE medium-dark gray #34383f.
Composition/framing: retain the exact square 4x4 equal-cell layout; keep every full body, ear, tail, hand, shoe and ribbon fully inside its original cell. Do not move or redraw the poses.
Constraints: crisp antialiased character edges, no white halo, no colored halo, no debris, no transparency, no grid lines.
Avoid: character redesign, pose changes, added or removed body parts, extra tail or ear, text, labels, numbers, borders, shadows, VFX, particles.
```

내장 이미지 생성 도구로 만들었고 외부 참고 이미지는 사용하지 않았다. 최초 생성 파일은
`exec-620e025e-7a47-46cc-9b29-2b28efc95e7d.png`, 배경 정리 파일은
`exec-c6394201-52b4-42ba-9d36-b786270d50be.png`다.
