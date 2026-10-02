# 유란 방어 모션 시안 검토

## 채택 및 등록

2026-10-02 사용자가 r02를 채택했다. 승인 원본은 보존하고 로컬에서 배경 제거·공통
크기·발 기준선을 적용해 `guard` SpriteFrames와 manifest에 등록했다. 방어 입력을
유지하는 동안 승인된 7번 자세를 고정하며, 전투 판정은 그림 프레임과 무관하다.

## 사용자 검토 대상

- 최종 검토본: `guard-r02.png`, `guard-r02.gif`.
- 재생 순서: 1–16, 83ms 간격의 검토용 GIF.
- 동작: 1–4 방어 진입, 5–11 정면의 가벼운 충격을 제자리에서 막기, 12–16 준비 자세 복귀.
- PNG SHA-256: `81ec926cdb7801b8eb30c7844623a82daa7369c4567cc3b64959c5ebabeb20cf`.
- GIF SHA-256: `b1f1629384a4fee5a392b0e60018bcbe79147e18bf7a31d5f41421e61267cd6d`.
- 내장 이미지 생성 도구를 사용했다. 승인된 유란 콘셉트만 외형 참조로 사용했다.

r01은 동작과 외형은 유지했지만 일부 큰 꼬리와 머리카락이 셀 가장자리에 가까웠다.
r02는 동일 동작을 더 작게 배치해 각 셀의 여백을 확보했다. 16개 포즈 모두 오른쪽을
향하며 사람 얼굴·손·발, 둥근 귀 두 개, 연결된 고리무늬 꼬리 한 개, 청록 보석과
의상을 유지한다. 8번째 포즈의 눈 감기와 상체 압축은 가벼운 충격 표현이며 공격이나
피격 판정을 만들지 않는다.

배경은 검토용 불투명 회색이며 미세한 명암이 남아 있다. 채택 뒤 기존 나비 절차와 같이
로컬에서 배경 제거·공통 크기·발 기준선을 정규화했다. 검토 파일 자체는 그대로 보존한다.

## r01 생성 프롬프트

```text
Use case: identity-preserve.
Asset type: Forest Arena 2D fighting-game animation review contact sheet, not runtime-ready.
Input image: the approved Yu-Ran concept is the sole identity and costume reference.
Primary request: Create exactly 16 sequential full-body key poses for Yu-Ran performing a grounded defensive guard animation. The sequence must read left-to-right, top-to-bottom: frames 1-4 enter guard, frames 5-11 hold and absorb one light frontal impact without moving location, frames 12-16 smoothly return to ready stance. She faces RIGHT throughout. Her forearms rise in front of her face and torso while her one oversized ringed tail curls behind and beside her as a protective counterbalance; no attack or counterattack.
Composition/framing: one square contact sheet with an exact 4 columns by 4 rows layout, 16 equal implied cells, row-major. Each complete pose independently centered inside its cell, uniform scale, stable planted foot baseline and root position. Entire hair, exactly two ears, hands, shoes, ribbons, and the complete tail must stay within its own cell with at least 12% blank padding on every side. No pose or pixel may cross into another cell. No visible grid lines.
Identity invariants: adult female three-head-tall human-form fighter; ash-silver hair; exactly two round brown weasel ears with white inner tufts; exactly ONE continuous oversized long brown-and-white ringed tail attached at the correct lower-back position; human face, human hands, human feet and plantigrade legs; brown, white, and black fur-collar street jacket; black cropped inner layer; white fitted shorts with black straps; black fingerless gloves; brown-white-black high-top sneakers; large black bow; teal ribbon accents; teal diamond belt gem; practical confident expression. Preserve the polished chibi game illustration style of the reference.
Backdrop: perfectly uniform opaque medium-dark gray #34383f in all blank space.
Constraints: clear small-screen silhouette; defensive pose must be distinct from idle and attack; subtle impact compression only, no displacement; no text, numbers, labels, borders, grid, UI, VFX, particles, shadows, halos, debris, or transparency.
Avoid: crop or cut-off body parts, cross-cell overlap, duplicated/split/disconnected/extra tail, extra ears, animal muzzle, animal face, paws, fur-covered limbs, digitigrade legs, weapons, shields, kicks, punches, attack pose, costume drift, camera angle changes, mirrored facing, or background variation.
```

내장 이미지 생성 결과: `exec-8c7a9989-2143-4975-9b64-58a184824327.png`.

## r02 배치 수정 프롬프트

```text
Use case: precise-object-edit.
Asset type: corrected Forest Arena Yu-Ran guard animation review contact sheet.
Primary request: Keep the exact same 16 Yu-Ran guard poses and their row-major order, but repair only the per-cell scale, placement, and background. The current sheet has oversized tails and hair too close to cell edges. Re-layout all poses into strict isolated cells with generous safe margins.
Composition/framing: exact square 4 columns by 4 rows, 16 equal implied cells. Treat every quarter-width by quarter-height rectangle as a hard boundary. Uniformly shrink each WHOLE pose independently to about 78% of its current size and center it within its own cell. Every complete tail, hair strand, ear, ribbon, glove, and shoe must remain inside only that cell with at least 12% blank padding left and right and 8% above and below. Stable planted foot baseline and root position. No pixels from one pose may enter another cell. No visible grid.
Invariants: preserve the same exact animation: frames 1-4 enter guard, 5-11 hold and absorb one light frontal impact, 12-16 return to ready; facing RIGHT; no attack. Preserve Yu-Ran's approved identity and polished chibi style: human face/hands/feet, ash-silver hair, exactly two round brown ears, exactly ONE continuous attached brown-and-white ringed tail, brown-white-black streetwear, teal belt gem and accents, black bow, high-top sneakers.
Backdrop: perfectly flat, uniform, opaque medium-dark gray #34383f with no gradient, floor line, vignette, shadows, or lighting variation.
Avoid: changing any pose or order, crop, cross-cell overlap, tail touching a cell edge, duplicated/split/disconnected/extra tail, extra ears, animal muzzle or paws, weapons, shields, punches, kicks, costume drift, text, labels, borders, grid lines, VFX, particles, shadows, halos, transparency.
```

내장 이미지 생성 결과: `exec-9acb6d10-666b-441a-950d-e396f6c238d0.png`.
