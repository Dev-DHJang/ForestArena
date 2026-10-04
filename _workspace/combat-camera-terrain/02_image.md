# 지형 이미지 제작 기록

## 생성과 선정

- 도구: Codex 내장 ImageGen, `stylized-concept` 모드
- 배경 원본: `_workspace/combat-camera-terrain/source/background.png`, 1672×941 RGB,
  SHA-256 `38326d887ef686f40b1ef58b6d63bb34c4dbad38e10e11dd7b88eba6a725e817`
- 지형 원본: `_workspace/combat-camera-terrain/source/terrain.png`, 1672×941 RGBA,
  SHA-256 `1a70cb9302cf302b83fc8834cbc57a7e61789a56e91a2cf56682ea205d23627a`
- 자동 선정 이유: 밝은 숲 협곡 배경의 중앙 대비가 낮아 작은 캐릭터가 잘 보이고, 지형은
  긴 1층과 정확히 절반 비율의 2층이 분리된 투명 실루엣이며 양끝 낭떠러지가 분명하다.

배경 프롬프트:

> Use case: stylized-concept. Asset type: Forest Arena 2D side-view combat stage background,
> landscape 16:9. Create an original bright fantasy forest canyon arena background for a mobile
> 2D platform fighting game. A broad magical forest valley with layered distant cliffs, soft
> waterfalls, airy mist, luminous foliage, and a deep readable chasm in the lower region. Keep the
> central combat region visually calm and uncluttered so small character sprites remain readable.
> Polished non-pixel digital game background illustration, crisp large shapes, soft atmospheric
> depth, original visual design. Exact wide 16:9 composition. No characters and no actual walkable
> platform silhouettes; this is the distant background layer only. Leave the middle and
> lower-middle relatively low contrast for foreground terrain and fighters. Extend scenery cleanly
> to all four edges for camera panning. Clear warm daylight, inviting adventurous mood. Sky blue,
> mint, forest green, teal shadow, restrained warm gold accents. No characters, animals, UI, text,
> logos, watermark, frame, embedded platform geometry, modern objects, recognizable third-party IP
> or artist imitation. Production-ready game asset.

지형 프롬프트:

> Use case: stylized-concept. Asset type: transparent foreground terrain layer for a 2D side-view
> mobile platform fighting arena, exact wide 16:9 canvas. Create only two original floating forest
> terrain pieces on a genuinely transparent background: one long lower fighting island spanning
> about two thirds of the canvas width near the lower third, and one centered upper one-way platform
> exactly half the lower island's length, positioned clearly above it. Thick grassy top edges,
> readable pale stone and dark teal rock cliff faces, restrained roots and small plants. The lower
> island must have two unmistakable vertical cliff ends and empty transparent space beyond both
> ends to communicate ring-out drops. The upper platform must be thin enough to read as pass-through
> gameplay terrain. Polished non-pixel digital game art matching a bright fantasy forest arena,
> crisp silhouettes and strong mobile readability. Strict side elevation, nearly horizontal top
> walking surfaces, centered and symmetrical gameplay composition. Keep all decoration inside the
> terrain silhouettes. No perspective tilt. Clear warm daylight with cool teal rock shadows. Fresh
> grass green, mint highlights, pale gray stone, deep teal shadow, subtle warm gold. Actual alpha
> transparency outside terrain; no background scenery, sky, fog field, characters, animals, UI,
> text, logo, watermark, bridges, extra platforms, ground connecting to the canvas edges,
> recognizable IP or artist imitation. Production-ready transparent PNG.

## 후처리와 런타임 경로

`tools/forest_arena/prepare_forest_ledge_art.py`가 생성 원본을 보존한 채 배경을 16:9로
중앙 맞춤하고 지형의 약한 알파 잡음을 제거한다. 두 지형 조각은 독립적으로 크기를 맞춰
1층 `x=100..1180, y=586`, 2층 `x=370..910, y=418`의 충돌 보행면과 일치시킨다.
world 그림 범위는 `(-816,-528)..(2096,1110)`이다.

| 품질 | 배경 SHA-256 | 지형 SHA-256 |
| --- | --- | --- |
| high 1920×1080 | `d5563dc2d670537e3d906533a21b1713881e751bd86418772b16a490390eeb41` | `24bb48cc19b52e4d648a2056475644deb7c25ac75d423c1c22934a8faaa7f8cb` |
| medium 1280×720 | `5fe558668067695312c4c766d240ed7b831d8363c1f5b97dae69004be2cdb2ce` | `ca894b59c3daaeb4b65add598eac6f991e36c0799f96bd9f8813bb7fec8017d1` |
| low 960×540 | `def637204e021f9a012671cd9bc245020f10cb739671c7c652152f02ee32bf76` | `70a9b21c9fb2dcc6d0cdd4a5fbc1c53a6c397eec5beeda192f4578e8490226dd` |

배경은 기존 `fa.background.combat.training.arena`, 지형은 새
`fa.terrain.combat.forest-ledge` 논리 ID로 등록했다. 품질별 파일은
`forest_arena/assets/quality/<quality>/background/`와 `terrain/`에 있으며 이미지가
전투 판정을 소유하지 않는다.
