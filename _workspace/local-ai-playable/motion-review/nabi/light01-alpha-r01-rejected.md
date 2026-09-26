# 승인 모션 투명화 검사 — 수정 필요

- 승인 원본: `light01-r04.png`. 2026-09-26 사용자가 모션을 승인했다.
- 내장 imagegen의 background-extraction 편집으로 배경만 제거하도록 요청했다.
- 결과: `light01-alpha-r01-rejected.png`. 신체 외부에 자주색·파란색 잡픽셀과 흰 테두리가 남아 시각 검사 실패. 런타임에 등록하지 않았다.
- 생성 원본: `exec-a58999cf-61b1-4ccb-b6fd-8fdec0395193.png`. 사용자 승인 디자인의 파생 작업이며 외부 권리 확인을 추가로 주장하지 않는다.
- 다음 작업: 승인된 그림을 재생성하지 않고 로컬 이미지 처리로 배경 제거·프레임 정규화를 수행하는 방식에 대한 사용자 확인. 승인 디자인은 유지하고 결과 품질만 다시 검사한다.

## 사용 프롬프트

Use case: background-extraction. Edit target: the supplied approved Nabi 16-frame attack sprite sheet. Remove only the opaque gray background to genuine RGBA transparency. Preserve all sixteen character drawings EXACTLY, their motion, positions, row-major 4x4 arrangement, size, white hair, white cat ears and tail, black and purple clothing, hands and shoes. Do not redraw, redesign, add particles, introduce a checkerboard or colored matte. Clean antialiased alpha edges, no gray/white/purple halo or loose pixels. Keep white character features opaque. No shadows, labels, grid lines, or new objects. Output transparent PNG with the same square 4 by 4 layout and all extremities intact. This is background removal for user-approved game sprites, not a new design.
