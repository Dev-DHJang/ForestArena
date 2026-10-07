# 확장 숲 지형과 전투 조작 이미지

## 지형 생성

- 도구: Codex 내장 ImageGen
- 원본: `source/terrain-expanded.png`, 1672×941 RGBA
- 원본 SHA-256: `367ea5eb4f3e6ec7b7d502f82943b0134db26c0ea1022cd35dea2eea46e763b1`
- 배경 원본은 기존 승인 `_workspace/combat-camera-terrain/source/background.png`와 같은
  파일이며 SHA-256은 `38326d887ef686f40b1ef58b6d63bb34c4dbad38e10e11dd7b88eba6a725e817`이다.
- 생성 내용: 투명 16:9 캔버스에 긴 1층과 서로 다른 높이·길이의 숲 발판 네 개. 캐릭터,
  글자, 로고와 배경은 넣지 않았다.

`tools/forest_arena/prepare_forest_ledge_art.py`는 생성 원본의 다섯 조각을 분리해
`StageData` v2의 보행면 x·y·폭에 맞추고 high·medium·low 변형을 만든다. 생성 그림은
전투 판정을 정하지 않는다.

| 품질 | 결과 SHA-256 |
| --- | --- |
| high 1920×1080 | `f01f3935a3407fb6c82a1ef0f94690dca9c31c14f129020301567bf4c92e12ae` |
| medium 1280×720 | `42edc1cd4f1a301ada4f1a49d68510eab8cfe7b333f47d6bb97c8cb0008b0f9e` |
| low 960×540 | `20610f5166da7542ce75495d91963afca697a628dbb1d63bb6b6e81b33eeba56` |

## 터치 조작

승인 `assets/ui/forestlight-v01/dpad-*.svg`를 기존 논리 ID에 연결했다. 행동 버튼은 같은
Forestlight 유리·잎 형태의 중립 기본·눌림 SVG로 만들고 행동 이름은 런타임 글자로 유지했다.
