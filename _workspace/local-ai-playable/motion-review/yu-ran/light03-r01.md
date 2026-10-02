# 유란 약공격 3단 r01 검토 시안 — 반려

## 상태와 확인

- 독립 QA에서 9번 꼬리 끝 잘림과 10번 셀의 이전 꼬리 조각 침범을 확인해 반려했다. 후속본으로 교체했으며 런타임과 manifest에는 등록하지 않았다.
- 기술: `yu-ran-light-03`, `attack_light_combo_03`. 준비 6 / 활성 3 / 회복 12 tick인 피니시 공격이다.
- 1–5번 몸을 낮춰 감기, 6–8번 한 개의 큰 꼬리로 오른쪽 수평 휩쓸기, 9–12번 후속 자세, 13–16번 회수를 의도했다.
- 승인 외형의 귀 두 개·꼬리 한 개·인간형 손발·의상·청록 보석을 유지한다. 타격 구간은 1·2단보다 넓고 강하게 구별된다.
- 꼬리를 오른쪽으로 뻗는 프레임에서도 몸에 붙은 한 개의 꼬리로 보인다. 실제 재생 연속성과 셀 경계는 승인 뒤 정규화 과정에서 다시 검사한다.
- 1262×1246 RGB 검토 이미지다. 정확한 셀 포장·투명 배경·발 기준선은 승인 뒤 처리한다.
- SHA-256: `75bfa8596ac9a54b910405de80129a2756ceec2725a1f0fae0fb7748346efc17`.
- `light03-r01.gif`는 원본을 바꾸지 않은 256×256, 16프레임 검토 재생본이다. SHA-256은 `0daf147ff85912d4f23cc5b222e5601f4a35810860a902a4bf606f5851d19a64`다.

## 생성 프롬프트

```text
Use case: stylized-concept.
Asset type: Forest Arena 2D animation review sprite sheet, not a runtime asset.
Primary request: Create a NEW 16-pose review sheet for Yu-Ran light combo attack 03, the grounded finisher: one powerful waist-height sweep with her single oversized ringed tail toward the RIGHT.
Input images: Image 1 is the approved Yu-Ran identity/costume reference. Image 2 is only the combo 01 style/scale/foot-baseline reference; do not repeat its palm jab.
Scene/backdrop: uniform opaque medium-dark gray #34383f.
Subject: approved adult female three-head-tall human-form weasel fighter, ash-silver hair, exactly two round brown weasel ears with white inner tufts, exactly ONE oversized long brown-and-white ringed tail, brown/white/black fur-collar street jacket, black cropped inner layer, white fitted shorts with black straps, black fingerless gloves, brown-white-black high-top sneakers, large black bow and teal ribbon accents, readable teal diamond belt gem.
Style/medium: polished chibi game sprite animation concept matching the references, clean antialiased silhouette.
Composition/framing: exactly 16 equal cells in a square 4x4 grid, row-major, one full-body pose per cell. All remain readable as facing RIGHT in a side/three-quarter view. Stable root position and foot baseline, consistent scale and proportions, at least 10% padding, no neighboring-cell overlap.
Motion progression: frames 1-5 lower the stance and coil hips/shoulders left while the one tail curls behind; frames 6-8 pivot the torso and drive that same single thick ringed tail in a broad horizontal sweep at waist height to the right; frames 9-12 hold a clear follow-through with the tail extended right and hands guarding; frames 13-16 recover to the wide ready stance. Feet pivot but do not leave the floor. This depicts startup 6 ticks / active 3 / recovery 12 ticks, but print no numbers.
Constraints: this is the third-hit finisher and must read stronger and broader than combo 01/02. Preserve exact approved identity, human face/hands/feet/body, exactly two ears, exactly one tail, costume and teal gem. Make all 16 poses progressive. Keep the entire tail and all body parts inside each cell.
Avoid: extra tails, tail duplication, tail splitting, kicks, leaps, animal muzzle, animal face, fur-covered limbs, paw hands or feet, digitigrade legs, extra ears, copied brand/emblem, text, labels, grid lines, borders, shadows, slash VFX, particles, opponent, weapons, camera movement, white outline, halo, debris.
```

내장 이미지 생성 도구 결과는 `exec-f31157a1-1676-4ba4-abe8-3f314ab8294c.png`다.
