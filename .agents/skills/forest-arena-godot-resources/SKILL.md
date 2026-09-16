---
name: forest-arena-godot-resources
description: Forest Arena Godot 리소스의 논리 ID·품질 변형·Autoload 경계와 검증을 관리한다.
---
# Forest Arena Godot 리소스

## 사용 시점

- `res://forest_arena/`의 리소스 카탈로그, 논리 ID, 품질 변형, `ForestArenaResources` Autoload 또는 검증기를 변경할 때 사용한다.
- 기존 `assets/character/`, `assets/ui/generated/`의 승인 자산을 대체하거나 승인 상태를 바꾸는 작업에는 사용하지 않는다.

## 필수 입력

- `docs/engineering/godot/setup.md`, `docs/engineering/godot/resource-rules.md`, 소비자와 품질 요구.
- 공용 ID·스키마 변경이면 `01_contract.md`와 모든 생산자·소비자 목록.

## 작업 흐름

1. 경로 대신 `ForestArenaResources`의 논리 ID로 리소스를 등록·소비한다.
2. `high`·`medium`·`low` 품질 변형과 registry의 ID 중복·누락을 함께 검토한다.
3. 주인공 정체성과 승인 경계를 보존하고 UI 텍스트는 네이티브 텍스트로 유지한다.
4. Autoload와 registry 변경은 headless Godot 로드 및 소비자 경계를 확인한다.

## 산출물과 검증

- registry·품질 프로필·Autoload 또는 이를 설명하는 필요한 증적.
- 리소스 또는 이를 소비하는 UI 변경 뒤 `python tools/forest_arena/verify_godot_resources.py --project-root .`를 실행한다.
