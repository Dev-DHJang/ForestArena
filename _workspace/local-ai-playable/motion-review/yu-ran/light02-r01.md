# 유란 약공격 2단 r01 검토 시안 — 반려

## 상태와 확인

- 독립 QA에서 7번 주먹 잘림과 3→4번 준비 동작 되돌림을 확인해 반려했다. r02로 교체했으며 런타임과 manifest에는 등록하지 않았다.
- 기술: `yu-ran-light-02`, `attack_light_combo_02`. 준비 4 / 활성 3 / 회복 7 tick이다.
- 1단의 손바닥 찌르기와 구별되는 뒤손 수평 치기를 의도했다. 1–4번 준비, 5–7번 타격, 8–16번 회수다.
- 잿빛 은발, 둥근 갈색 귀 두 개, 고리무늬 꼬리 한 개, 인간형 손발, 청록 보석과 승인 의상을 유지한다. 두 발은 지면에 남는다.
- 동작은 짧은 뒤손 치기보다 곧은 주먹으로 읽힐 여지가 있다. 승인 시 동작 의도도 함께 확정해야 한다.
- 1262×1246 RGB 검토 이미지다. 정확한 셀 포장·투명 배경·발 기준선은 승인 뒤 처리한다.
- SHA-256: `b689fa569d8b13f8d7bd9b1feb8468ee3e8ffd9ce50a047550fac427eda30c0e`.
- `light02-r01.gif`는 원본을 바꾸지 않은 256×256, 16프레임 검토 재생본이다. SHA-256은 `b8d75be179a8be03add59d456cb70abb0b92efdbf4759428e45af5be975917c7`다.

## 생성 프롬프트

```text
Use case: stylized-concept.
Asset type: Forest Arena 2D animation review sprite sheet, not a runtime asset.
Primary request: Create a NEW 16-pose review sheet for Yu-Ran light combo attack 02, a compact grounded rear-hand backfist to the RIGHT that clearly follows combo 01 but is a different attack.
Input images: Image 1 is the approved Yu-Ran identity/costume reference. Image 2 is only the approved-style combo 01 review for consistent scale, facing, foot baseline, and ready stance; do not repeat its open-palm jab.
Scene/backdrop: uniform opaque medium-dark gray #34383f.
Subject: approved adult female three-head-tall human-form weasel fighter, ash-silver hair, exactly two round brown weasel ears with white inner tufts, exactly ONE oversized long brown-and-white ringed tail, brown/white/black fur-collar street jacket, black cropped inner layer, white fitted shorts with black straps, black fingerless gloves, brown-white-black high-top sneakers, large black bow and teal ribbon accents, readable teal diamond belt gem.
Style/medium: polished chibi game sprite animation concept matching the references, clean antialiased silhouette.
Composition/framing: exactly 16 equal cells in a square 4x4 grid, row-major, one full-body pose per cell. All face RIGHT in stable side/three-quarter view. Identical root position, foot baseline, scale, and limb length. At least 10% padding; no neighboring-cell overlap.
Motion progression: frames 1-4 rotate the torso slightly left and chamber the rear/right fist near the shoulder while the lead hand guards; frames 5-7 snap a short horizontal backfist across chest height to the right; frames 8-16 follow through and return to a tail-ready stance. Both feet stay planted; hips and shoulders visibly rotate. The single oversized ringed tail counterbalances in one smooth arc and remains readable. This depicts startup 4 ticks / active 3 / recovery 7 ticks, but print no numbers.
Constraints: preserve exact approved identity, human face/hands/feet/body, two ears, one tail, costume and teal gem. Make all 16 poses progressive and distinct. Keep every body part fully inside its cell.
Avoid: repeating combo 01 palm jab, kicks, leaps, spins, animal muzzle, animal face, fur-covered limbs, paw hands or feet, digitigrade legs, extra ears, extra tails, copied brand/emblem, text, labels, grid lines, borders, shadows, VFX, particles, opponent, weapons, camera movement, white outline, halo, debris.
```

내장 이미지 생성 도구 결과는 `exec-5c6ce582-62c7-44ac-98c7-e972dab7ab02.png`다.
