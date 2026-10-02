# 유란 약연계 수정 시안 검토

## 채택 결과

2026-10-02 사용자가 아래 세 시안을 모두 채택했다. 승인 원본을 보존한 채 투명 배경·
공통 크기·발 기준선으로 정규화해 runtime과 manifest에 등록했다. 아래 표의 해시는
변경하지 않은 검토 원본과 GIF를 가리킨다.

| 기술 | 검토본 | 재생 순서 | PNG SHA-256 | GIF SHA-256 |
| --- | --- | --- | --- | --- |
| `yu-ran-light-01` | `light01-r02` | 1–16 | `d1624b7fe91e41510b76cf71460182d0fc1530573c8a4dd8ab8810881e3ffbda` | `36dce289646d029b83adf4b9ddf0db01a678f8b1249628103e61211c525ecf5a` |
| `yu-ran-light-02` | `light02-r02` | 1,2,4,5,6,7,3,8–16 | `063b016531cb4f6b3564041357d54c3c2f6b7cf52e463380fdf03e12533bd1c2` | `f3513dd5a18dbd98de5992ab3a323db2bd7f2cf38389ffc6411e4e41ee92b99f` |
| `yu-ran-light-03` | `light03-r03` | 1–16 | `c331336c7fcd7318592354e9b93c5a3edc6c372e8d62220dd3ceb7ce39660204` | `ed6b8beb283d8e59eac13796fb5412b2bead2aa0cfc21c50feaa79f50e445014` |

- 1단은 손바닥 찌르기, 2단은 뒤손 치기, 3단은 한 개의 큰 꼬리 수평 휩쓸기 피니시다.
- r01의 1단 손 여백, 2단 주먹 잘림·준비 순서, 3단 꼬리 잘림·이웃 셀 침범을 수정했다.
- 2단은 시트 원본 3번이 일찍 뻗으므로 위 표의 검토·향후 정규화 순서를 사용한다.
- 2단은 짧은 뒤손 치기보다 곧은 주먹처럼 읽힐 수 있다. 사용자 승인 시 이 동작 판독도 함께 확정한다.
- PNG는 검토 시트이고 GIF는 원본을 변경하지 않은 256×256, 16프레임 재생본이다. 실제 AttackData tick과 적중 판정을 정하지 않는다.

## 1단 r02 편집 프롬프트

```text
Use case: precise-object-edit.
Asset type: revised Forest Arena animation review contact sheet.
Primary request: Repair only the layout of this exact Yu-Ran combo-01 palm-jab 4x4 sheet so every one of the 16 complete poses has safe cell padding. In particular, the extended palm around frame 6 must not touch or cross the implied right cell boundary.
Composition/framing: exact square 4x4 equal-cell grid, row-major. Uniformly reduce and center every complete pose to about 85% of current size inside its own cell. At least 10% empty padding on every side. No hand, hair, ear, tail, shoe, ribbon, or body part may touch or cross a cell boundary. Stable root position and foot baseline.
Invariants: preserve all 16 pose actions and order, frames 1-4 preparation, 5-7 short open-palm jab to the RIGHT, 8-16 recovery; preserve approved Yu-Ran identity, human face/hands/feet, costume, teal gem, exactly two round brown ears, and exactly ONE continuous brown-and-white ringed tail. Preserve planted feet and the existing visual style.
Backdrop: one uniform opaque medium-dark gray #34383f.
Avoid: changing the attack, cropping, extra/duplicated/split tail, extra ears, animal muzzle or paws, costume changes, frame-order labels, text, grid lines, borders, VFX, particles, shadows, halos, debris, transparency.
```

내장 이미지 생성 결과: `exec-5713c516-215f-42a7-b891-2dc611a63c6c.png`.

## 2단 r02 편집 프롬프트

```text
Use case: precise-object-edit.
Asset type: revised Forest Arena animation review contact sheet.
Primary request: Repair only the layout and preparation continuity of this exact Yu-Ran combo-02 4x4 sheet. In the current sheet frame 7's fist touches/crosses the right cell edge, and frame 4 returns toward ready after frame 3 already extends. Make frames 1-4 a strictly progressive chamber with no early extension, frames 5-7 a progressive compact rear-hand backfist to the RIGHT, and frames 8-16 a smooth recovery.
Composition/framing: exact square 4x4 equal-cell grid, row-major. Uniformly reduce and center every complete pose to about 85% of current size inside its own cell. At least 10% empty padding on all sides. No fist, hair, ear, tail, shoe, ribbon, or body part may touch or cross a cell boundary. Stable foot baseline and root position.
Invariants: preserve approved Yu-Ran identity, human face/hands/feet, costume, teal gem, exactly two round brown ears, exactly ONE continuous brown-and-white ringed tail, right-facing grounded action, planted feet, and the compact backfist concept. Preserve the existing visual style.
Backdrop: one uniform opaque medium-dark gray #34383f.
Avoid: straight open-palm jab, ready-pose reversal between frames 1-4, cropping, extra/duplicated/split tail, extra ears, kicks, leaps, spins, animal muzzle or paws, costume changes, frame-order labels, text, grid lines, borders, VFX, particles, shadows, halos, debris, transparency.
```

내장 이미지 생성 결과: `exec-0bc2a4c9-fa78-4073-afac-f18e309f75e3.png`.

## 3단 r03 편집 프롬프트

```text
Use case: precise-object-edit.
Asset type: corrected Forest Arena 4x4 animation review contact sheet.
Primary request: Re-layout this exact 16-pose Yu-Ran tail-sweep sheet into STRICT ISOLATED CELLS. The image is 4 columns by 4 rows. Treat every quarter-width by quarter-height rectangle as a hard clipping boundary. No pixel of any pose may enter another rectangle.
Critical repair: in row 3, columns 1-3 (poses 9, 10, 11), the long tail currently crosses the vertical cell boundaries. Shrink EACH WHOLE pose independently around its own center until the entire character plus complete tail fits well inside only that pose's own cell. Do not leave any fragment from pose 9 in pose 10 or from pose 10 in pose 11.
Composition/framing: exact square 4x4 equal-cell layout. Every full pose, including the longest horizontal tail poses, must occupy no more than 70% of its cell width and 78% of its cell height, centered independently in that cell. At least 15% blank padding at left and right, at least 10% above and below. Stable foot baseline within each row. Uniform pose scale across all 16 cells; it is acceptable and desired for the character to be visibly smaller than the reference.
Invariants: preserve the same 16 action poses and row-major order, the coil, one-tail horizontal sweep, follow-through, and recovery; preserve Yu-Ran's human face/hands/feet, outfit, teal gem, exactly two round brown ears, and exactly ONE continuous attached brown-and-white ringed tail.
Backdrop: perfectly uniform opaque medium-dark gray #34383f across all blank space.
Avoid: any cross-cell overlap, cropped tail tip, leftover tail fragment, duplicated/split/extra tail, extra ears, changing the action, changing costume, text, labels, visible grid lines, borders, VFX, particles, shadows, halos, debris, transparency.
```

내장 이미지 생성 결과: `exec-6560eaae-bfd7-4828-9702-8d63894cb820.png`.
