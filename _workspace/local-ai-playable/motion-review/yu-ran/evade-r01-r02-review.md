# 유란 회피 모션 시안 검토

## 채택 및 등록

2026-10-02 사용자가 r02를 채택했다. 승인 원본은 보존하고 로컬에서 배경 제거·공통
크기·발 기준선을 적용해 `evade` SpriteFrames와 manifest에 등록했다. 16프레임은 기존
12 tick 회피에 맞춰 표시하며 이동·무적 판정 시간을 바꾸지 않는다.

## 사용자 검토 대상

- 최종 검토본: `evade-r02.png`, `evade-r02.gif`.
- 재생 순서: 1–16. GIF는 검토용으로 프레임당 60ms이며 실제 회피 12 tick을 정하지 않는다.
- 동작: 1–3 압축, 4–7 낮은 숙임, 8–11 꼬리로 균형을 잡는 낮은 회피, 12–16 복귀.
- PNG SHA-256: `80b00f85ffdb0d3e857b8dbd8389ce947de961e5626b3d66fbd6a7d06d0b9b02`.
- GIF SHA-256: `ee5306ddd671316ba2047e2508607d21a12bdd5b8cf4e4e89b83e596c532a1e7`.
- 내장 이미지 생성 도구를 사용했고 승인된 유란 콘셉트만 외형 참조로 사용했다.

r01은 동작 흐름과 외형을 유지했지만 깊게 숙인 구간의 꼬리가 셀 경계에 가까웠다.
r02는 동작을 바꾸지 않고 포즈를 축소·재배치했다. 16개 포즈 모두 오른쪽을 향하되
왼쪽·오른쪽 어느 쪽 이동에도 사용할 수 있도록 특정 방향으로 몸을 던지지 않는다.
사람 얼굴·손·발, 둥근 귀 두 개, 연결된 고리무늬 꼬리 한 개, 청록 보석과 의상을
유지한다. 배경의 미세한 명암은 사용자 채택 뒤 로컬 배경 제거에서 없앤다.

검토 원본은 runtime 파일로 직접 사용하지 않는다. 정규화한 파생 시트만 runtime과
manifest에 등록했다.

## r01 생성 프롬프트

```text
Use case: identity-preserve.
Asset type: Forest Arena 2D fighting-game animation review contact sheet, not runtime-ready.
Input image: the approved Yu-Ran concept is the sole identity and costume reference.
Primary request: Create exactly 16 sequential full-body key poses for Yu-Ran performing a fast grounded evasive slip/duck that can accompany horizontal movement in either direction. Read left-to-right, top-to-bottom: frames 1-3 compress from ready stance, frames 4-7 drop into a very low compact duck with torso centered and knees bent, frames 8-11 pass through a low tail-balanced slip without attacking, frames 12-16 recover smoothly to ready stance. She faces RIGHT throughout, but the body action must be direction-neutral enough that gameplay may move her left or right. No roll, somersault, jump, attack, or teleport.
Composition/framing: one square contact sheet with exact 4 columns by 4 rows, 16 equal implied cells, row-major. Each complete pose independently centered within its own cell at uniform scale. Stable foot baseline and root position; keep both shoes visually grounded except for a subtle weight shift. Entire hair, exactly two ears, hands, shoes, ribbons, and the complete tail must stay inside only that pose's cell with at least 14% blank padding at left and right and 9% above and below. No pose pixel may cross into another cell. No visible grid.
Identity invariants: adult female three-head-tall human-form fighter; ash-silver hair; exactly two round brown weasel ears with white inner tufts; exactly ONE continuous oversized long brown-and-white ringed tail attached at the lower back; human face, human hands, human feet and plantigrade legs; brown-white-black fur-collar street jacket; black cropped inner layer; white fitted shorts with black straps; black fingerless gloves; brown-white-black high-top sneakers; large black bow; teal ribbon accents; teal diamond belt gem. Preserve the polished chibi game illustration style and confident practical expression of the reference.
Motion readability: the large tail draws close to the torso during the deepest duck, then extends as a counterbalance during recovery; silhouette must remain readable on a small Android screen. Runtime movement and invulnerability timing are not determined by these frames.
Backdrop: perfectly uniform opaque medium-dark gray #34383f in all blank space.
Avoid: directional lunge, attack pose, punch, kick, weapon, shield, airborne pose, acrobatics, roll, spin, afterimages, text, labels, borders, grid, UI, VFX, speed lines, particles, shadows, halos, debris, transparency, crop, cross-cell overlap, duplicated/split/disconnected/extra tail, extra ears, animal muzzle, animal face, paws, fur-covered limbs, digitigrade legs, costume drift, camera angle changes, or mirrored facing.
```

내장 이미지 생성 결과: `exec-757a06e5-7710-459d-a5cb-76ff4b36b720.png`.

## r02 배치 수정 프롬프트

```text
Use case: precise-object-edit.
Asset type: corrected Forest Arena Yu-Ran evade animation review contact sheet.
Primary request: Preserve the exact same 16 poses, action, facing, identity, and row-major sequence from this evade sheet. Repair only each pose's scale and placement so every full pose has safe blank margins inside its own cell.
Composition/framing: exact square 4 columns by 4 rows with 16 equal implied cells. Treat each quarter-width by quarter-height rectangle as a hard boundary. Shrink each WHOLE pose independently to about 80% of current size, then center it within its own cell while keeping a stable foot baseline. The complete tail, all hair, both ears, fingers, ribbons, and both shoes must remain in only that cell with at least 12% blank padding on left and right and 8% above and below. No pixel from one pose may cross into another cell. Uniform character scale across all cells. No visible grid.
Invariants: frames 1-3 compress, 4-7 very low compact duck, 8-11 low direction-neutral tail-balanced slip, 12-16 recover; faces RIGHT; no attack and no airborne motion. Preserve human face/hands/feet, ash-silver hair, exactly two round brown ears, exactly ONE continuous attached brown-and-white ringed tail, approved brown-white-black streetwear, teal gem and accents, black bow, sneakers, and polished chibi style.
Backdrop: flat opaque medium-dark gray #34383f, as uniform as possible.
Avoid: changing the motion or order, directional lunge, crop, cross-cell overlap, tail touching a cell edge, duplicated/split/disconnected/extra tail, extra ears, animal muzzle or paws, roll, jump, spin, attack, weapon, shield, text, labels, borders, grid, VFX, speed lines, particles, shadows, halos, transparency, costume drift, camera change, mirrored facing.
```

내장 이미지 생성 결과: `exec-5ec90018-460c-49e7-abea-81993ba062fa.png`.
