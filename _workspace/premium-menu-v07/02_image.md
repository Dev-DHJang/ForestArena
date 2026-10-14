# v07 메뉴 전용 숲 배경 제작 기록

## 요청과 제작 기준

- 작업 날짜: 2026-10-14 (Asia/Seoul).
- 현재 단계: Phase 6 오프라인 전체 흐름. 이번 산출물은 Penpot 설계용이며 Godot 리소스·런타임 자산 등록은 바꾸지 않는다.
- 적용 스킬: `imagegen`, `forest-arena-image-design`. 승인된 v07 계획의 어두운 메뉴 변형을 기존 밝은 비전투 화면과 구분해 제작했다.
- 제작 방식: OpenAI 내장 `image_gen`으로 자산마다 별도 생성. 외부 이미지·게임 화면을 입력하지 않았고 CLI/API 대체 경로도 사용하지 않았다.
- 요청 출력: 가로 16:9, 1920×1080 이상. 첫 원화는 이 크기를 요청했고 나머지는 3840×2160 또는 1920×1080 이상을 명시했다. 실제 도구 출력은 아래와 같이 1672px 너비다. 원본을 강제 확대하거나 최소 1920px를 확보했다고 기록하지 않는다.
- 캐릭터·글자·로고·UI·현대 전자기기·총기·차량·장신구 등급 단서 없이 독창적인 숲 공간을 만들었다. 승인 캐릭터와 기존 생성 자산은 수정하지 않았다.

## 납품 파일과 실제 해상도

| 작업용 이미지 이름 | 파일 | 실제 크기 | PNG 색상 | SHA-256 |
| --- | --- | --- | --- | --- |
| `IMG/bg/character-room` | `assets/ui/premium-menu-v07/backgrounds/character-room-v07.png` | 1672×940 | RGB, 불투명 | `5b7c4644de8667aaed0b95dae807e44afc2593da4bf6eb4bdfbe82e5895be286` |
| `IMG/bg/accessory-workshop` | `assets/ui/premium-menu-v07/backgrounds/accessory-workshop-v07.png` | 1672×941 | RGB, 불투명 | `ec8686310131bd9d63171bf1e171bab39fe7d0932b2518f72ffb26160e246cc0` |
| `IMG/bg/shop-market` | `assets/ui/premium-menu-v07/backgrounds/shop-market-v07.png` | 1672×941 | RGB, 불투명 | `459b4e81b5a058dae23362698d83b3244a418f62fd2f263a424ba7f74983d44c` |
| `IMG/bg/archive` | `assets/ui/premium-menu-v07/backgrounds/archive-v07.png` | 1672×941 | RGB, 불투명 | `99166a6da0eee6bd1c9623b186650c419c48e4f30ab2a7a9b5ab3fa1ec9c748b` |
| `IMG/bg/social-lodge` | `assets/ui/premium-menu-v07/backgrounds/social-lodge-v07.png` | 1672×941 | RGB, 불투명 | `743866a76e0a4caaf3ecebbb1dd5cbbfa790567472fb68bee13294d03b4a9a90` |
| `IMG/bg/observatory` | `assets/ui/premium-menu-v07/backgrounds/observatory-v07.png` | 1672×941 | RGB, 불투명 | `4b672b25525f3479113d2c736672bd72f5e27ab8cd8b56aaf2e50d81c493863a` |

`IMG/bg/character-room`과 `IMG/bg/accessory-workshop`은 기존 자산 요구표의 논리 슬롯이다. 나머지 4개 이름은 이번 Penpot 디자인 작업용 별칭이며 Godot 논리 ID로 새로 등록하지 않았다. 기존 CSV의 원래 출력 경로와 상태는 변경하지 않았고, 승인된 새 버전 경로에 별도 납품했다.

## 원본 출처와 후편집

- 출처: 이번 요청에 따라 내장 도구가 생성한 새로운 환경 원화. 제3자 캐릭터·로고·특정 게임 건축·특정 작가 스타일은 요청하지 않았다.
- 이용 권리 기록: 외부 자료 다운로드나 재사용 없음. AI 생성물이라는 출처를 유지하며 제3자 권리의 독립적인 법률 검토를 완료했다는 의미로 쓰지 않는다.
- 후편집: 없음. 생성 파일을 아래 원본 경로에서 프로젝트의 새 버전 경로로 바이트 그대로 복사했다. 생성 도구 원본도 보존했다.

- character-room: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-71b61d62-5138-4c73-889b-71425c844da4.png`
- accessory-workshop: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-84dfdb35-2fd4-4468-a0a3-920427c226f6.png`
- shop-market: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-cecf6ca4-a395-4bb7-a39a-fcb1a89c8ecd.png`
- archive: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-d9203971-2e02-44a7-b46c-c5a1a7acdede.png`
- social-lodge: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-8bbfc983-e739-494a-80ac-8e716879fa42.png`
- observatory: `/Users/jdh/.codex/generated_images/01a13627-8239-71e3-83a0-ac6fd93b9cae/exec-d8e97e88-a2c8-4c9a-b244-b9cb05ae17f8.png`

## UI 배치 규격과 검토

- 기본 보드 1920×1080에 비율을 유지해 채운다. 실제 원본 비율은 16:9와 약간 차이가 있으므로 늘려 찌그러뜨리지 않고 중앙 기준으로 아주 작은 가장자리만 잘라 쓴다.
- 1280×720 출력은 원본보다 작으므로 비율을 유지해 축소한다. 20:9 비교 보드는 원본을 늘리지 않고 양옆의 낮은 대비 여백과 패널을 이용한다.
- 밝은 창·등불 위에 주요 글자를 직접 놓지 않고 별도의 어두운 패널 또는 화면 전체의 얇은 색 덮개를 사용한다. 글자·버튼·상태·아이콘은 Penpot에서 편집 가능한 요소로 배치한다.
- 6개 모두 PNG를 직접 열어 구도·재질·여백·캐릭터 부재·읽을 수 있는 글자 부재·현대 금지 요소 부재를 육안 검토했다. 실제 작은 Android 화면 가독성은 완성된 화면 위에서 UI/QA 역할이 별도 확인한다.

| 배경 | 육안 검토 결과 |
| --- | --- |
| character-room | 곡선 목재 기둥·큰 빈 석재 무대·오른쪽 숲 창. 큰 승인 캐릭터 원화를 중앙에 놓을 공간 확보. 캐릭터·글자·UI·워터마크 없음. |
| accessory-workshop | 비스듬한 유리 벽과 오른쪽 황동 기계 작업대. 장신구 목록·큰 물체 그림의 빈 공간 확보. 캐릭터·글자·UI·워터마크 없음. |
| shop-market | 가지 천장 아래 넓은 회랑·양끝 유리 진열대. 상품 목록과 카테고리 배치를 위한 열린 중앙 바닥. 캐릭터·글자·UI·워터마크 없음. |
| archive | 왼쪽 고층 서가·원형 숲 채광창·오른쪽 읽기 테이블. 기록·미션·설정용 차가운 석재 공간. 캐릭터·글자·UI·워터마크 없음. |
| social-lodge | 넓은 숲 유리창·목재 바닥·오른쪽 작은 벽난로. 친구·프로필 정보를 얹을 차분한 중앙 여백. 캐릭터·글자·UI·워터마크 없음. |
| observatory | 열린 산·숲 전망과 오른쪽 순수 기계식 혼천의. 랭크·순위 화면의 수평 구도와 중앙 여백. 캐릭터·글자·UI·워터마크 없음. |

## 정확한 생성 프롬프트

### character-room

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 character-room background, production environment art only. Create an original sophisticated non-pixel fantasy forest character hall inside a vast living tree. Wide 16:9 landscape, request 1920x1080 or larger. Architectural arc of tall dark timber ribs and pale weathered stone around a softly illuminated empty circular practice dais near center-left; delicate bronze joinery, tall arched window on far right with layered deep forest silhouettes, a few empty display niches. Large calm low-detail negative space across center and left-middle for an editable character portrait and UI overlays; keep the upper 15 percent and outer 10 percent quiet. Premium painterly game environment concept art with polished material texture, convincing depth, subtle atmosphere, elegant restrained detailing. Desaturated ink teal #10181C dominant, dark jade #1C282C, tiny muted champagne-gold #D9C58E light accents, gentle cool rim light, subdued readable background exposure. No characters, animals, creatures, human silhouettes, text, letters, numbers, runes, signs, labels, logos, watermark, UI panels, icons, frames, electronics, screens, guns or vehicles. This must remain environment art rather than a UI mockup. No copying existing game architecture or specific artist style. Opaque background.
```

### accessory-workshop

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 accessory-workshop background, environment art only. Create an original elegant forest mechanical artisan workshop inside a large living tree. Output a landscape 16:9 high-resolution image at 3840x2160, at least 1920x1080; request true high resolution. Diagonal wide composition viewed from the empty quiet floor toward a dark smoked-glass workshop wall and recessed alcoves. Heavy charcoal blue-green timber rafters, oiled wood benches confined to far right and lower right, a few fine bronze hand-powered instruments, turned brass wheels, simple polished stone plinths, subtle faint tool silhouettes. Keep left and center 65 percent quiet dark negative space to support catalogue cards and a large foreground accessory image, no hero object in that space. Entire upper 15 percent calm and dark for a UI header. Sophisticated high-budget non-pixel painterly game environment concept art, nuanced authentic metal wood glass textures, convincing atmospheric depth, controlled bloom. Low-saturation ink teal #10181C, dark jade #1C282C, slight muted champagne-gold #D9C58E lamp light, a faint mint rim light. Mechanisms may be more developed than medieval craft but must be purely mechanical. No characters, animals, creatures, human silhouettes, guns, vehicles, modern electronics, screens, electricity cables, text, runes, numbers, labels, logos, watermarks, UI panels, buttons, icons, frames, rarity ornaments, stars or tiers. Distinct original environment architecture; no imitation of existing game architecture or named artist. Opaque background.
```

### shop-market

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 shop-market background, original environment art only. Create a polished high-budget fantasy forest market arcade with no people. A distinctive horizontal covered colonnade under a broad canopy of intertwined living branches, refined carved timber shopfronts and amber smoked-glass vitrines placed at far left and far right, quiet dark broad aisle stretching horizontally across the middle, soft leafy forest backdrop behind the stalls. Large open low-detail shadowed space across the central 60 percent intended for product grids and editable UI, upper 15 percent kept subdued for header. A few tasteful display cloths and closed cases in background edges only; no attention-grabbing goods or signs. Controlled warm lantern pools under the canopy, subtle forest mist and long soft reflected light on worn stone, authentic wood glass bronze materials. Premium non-pixel painterly fantasy game environment concept art, layered cinematic depth but clear calm structure. Landscape 16:9, output request 3840x2160 or at least 1920x1080. Ink teal #10181C and dark jade #1C282C dominate, desaturated cool mint foliage and restrained champagne-gold #D9C58E lighting. Elegant and inviting without excessive gilded ornament. No characters, animals, silhouettes, letters, numbers, writing, price labels, runes, banners with symbols, logos, watermark, UI, buttons, icons, frames, stars, rarity colors, modern electronics, guns or vehicles. Do not copy existing game environments or any specific artist. Opaque background.
```

### archive

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 archive background, environment illustration only. Create a distinctive original high-budget fantasy forest archive, a serene record gallery carved in cool layered stone and living dark tree roots. Wide asymmetrical composition: tall narrow deep teal wooden cabinets filled with closed plain unmarked books on the far left and receding left background, a softly illuminated circular stained translucent glass oculus above rear center, cool curved stone wall and a long low unoccupied reading desk at far right. Keep the front central 65 percent a large calm dark low-detail stone floor and wall with soft shadows suitable for editable catalogue lists and UI panels; reserve upper header area calm and subdued. No readable documents open, no mystical glyphs, no bright glowing hero object. Refined frosted glass, weathered slate, dark polished walnut, subtle bronze trim. Very sophisticated non-pixel painterly game concept art, elegant material craftsmanship, quiet atmospheric haze, convincing architectural depth. Desaturated ink teal #10181C and deep jade #1C282C, a little cool mint bounce and restrained muted champagne-gold #D9C58E lighting, dark enough to support readable foreground content. Landscape 16:9, request true 3840x2160 or at least 1920x1080. No people, characters, animals, creatures, human silhouettes, writing, letters, numbers, runes, labels, signs, logos, watermark, UI cards, buttons, icons, overlay borders, modern electronics, guns or vehicles. Original architecture, no imitation of specific game design or artist. Opaque background.
```

### social-lodge

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 social-lodge background, original environment art only. Create a distinctive refined fantasy forest social lodge, an intimate quiet communal lounge built into a living broad tree balcony. Wide landscape 16:9, requested true 3840x2160 or at least 1920x1080. Horizontal layered interior with dark carved wooden ceiling ribs across the top, curved cool smoked-glass windows along the left rear revealing rain-soft forest canopy, low unoccupied benches with desaturated teal cushions at far left, a restrained stone fireplace and empty round table confined to far right, a thin bronze lantern and soft ember glow. Large calm dark low-detail open central 60 percent floor space for editable social lists and profile UI. Keep entire upper 15 percent subdued, no overbright focal point in middle. Sophisticated non-pixel painterly premium game environment concept art, tactile dark oiled wood, woven cloth, smoke glass and cool slate, gentle volumetric depth, quiet welcoming atmosphere rather than gloomy dungeon. Palette ink teal #10181C and dark jade #1C282C with muted mint reflections and subtle champagne-gold #D9C58E firelight, low saturation, controlled highlights. No characters, people, animals, creatures, silhouettes, writing, letters, numbers, runes, notice boards, labels, signs, logos, watermark, UI, icons, buttons, overlay frames, stars, modern electronics, television, guns or vehicles. No copying a specific game design or artist style. Opaque background.
```

### observatory

```text
Use case: stylized-concept. Asset type: Forest Arena premium-menu-v07 observatory background, original environment art only. Create a distinctive magnificent but restrained forest overlook and mechanical observatory on a high living-tree terrace, no people. Wide panoramic landscape 16:9 image, output request true 3840x2160 or at least 1920x1080. View from a dark broad cool slate terrace over distant layered forest crowns and muted mountains under a tranquil blue-green evening sky. An elegant geometric bronze armillary sphere with plain unmarked rings mounted on a low stone pedestal confined to far right, a slender curved living-tree column and bronze railing at far left, shallow stone steps at lower right. Leave left-middle and central 65 percent clean and quiet with soft atmospheric forest gradients and shaded terrace for ranking UI. Upper 15 percent dark unobstructed sky suitable for header. This composition must feel more open and horizontal than an enclosed hall, dignified and aspirational without trophy decor. Premium non-pixel painterly fantasy game environment concept art, refined weathered stone and brushed bronze detail, layered deep atmospheric perspective, soft cool rim light and a very small muted champagne-gold #D9C58E glow from hidden lanterns. Dominant desaturated ink teal #10181C and dark jade #1C282C with pale restrained mint on distant haze. No characters, creatures, animals, people or silhouettes, text, letters, numbers, astronomical labels, runes, writing, logos, watermark, UI, button panels, icons, overlay frames, trophies, stars as ranking badges, guns, modern electronics, telescopic digital screens or vehicles. Astronomical device is purely hand-powered mechanical. Do not copy existing game architecture or named artist style. Opaque background.
```

## 미제작·제약

- 자동 파일 검사 `V07-BG-01` 통과: 6개 PNG 존재, PNG 헤더·실제 크기·RGB 불투명 형식, 기록의 경로·SHA-256, 생성 도구 원본과 프로젝트 복사본의 바이트 일치 확인.
- 이름 붙인 육안 재검사 `V07-BG-VISUAL-01` 통과: 6개 파일을 각각 열어 메뉴별 구도·재질·여백과 금지 요소 부재 확인. 완성 UI 글자 대비와 실기기 검사는 별도다.

- 요청한 6개 배경 파일은 모두 생성했다. 이미지 누락은 없다.
- 1920px 이상 원본 해상도 목표는 내장 도구 반환 크기 때문에 충족하지 못했다. 원본 1672px 너비로 전달하며 1920 보드 배치 시 보간된 표시가 필요하다.
- 화면 전용 아이콘·상품 그림·랭크 문장·희귀도 장식은 이번 이미지 작업에 포함하지 않았다.
- Penpot 저장·화면 출력·전환 연결·실기기 검증은 이 배경 제작 기록으로 통과 처리하지 않는다.

