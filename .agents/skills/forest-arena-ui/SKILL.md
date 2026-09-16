---
name: forest-arena-ui
description: Forest Arena 터치 UX·HUD·Penpot과 `ForestArenaResources` 기반 Godot 비전투 UI를 구현한다.
---

# Forest Arena UI

## 사용 시점

- 터치 입력 UX, Camera2D, HUD, 메뉴, 접근성 표현과 Godot 비전투 UI에 사용한다.
- 공격 판정, 원본 이미지·애니메이션·오디오 제작에는 사용하지 않는다.

## 필수 입력

- 현재 Phase, docs/gameplay/features-and-ux.md, 전투 상태·이벤트와 대상 화면 조건.
- 승인된 에셋 또는 플레이스홀더와 실패 상태.
- 비전투 작업이면 `docs/ui/non-combat-ui-v01.json`, `assets/ui/asset-requirements.csv`, `docs/engineering/godot/setup.md`, `docs/engineering/godot/resource-rules.md`.

## 작업 흐름

1. 현재 Phase의 최소 흐름과 표시 상태만 만든다.
2. 전투 데이터를 읽어 표현하고 피해·상태·승패를 계산하지 않는다.
3. 파이터, 위험 경계, 최대 줌아웃, 터치 영역과 safe area를 함께 검토한다.
4. 색상 외 상태 표시와 조절 가능한 흔들림·번쩍임을 유지한다.
5. Penpot 작업은 references/penpot-workflow.md를 읽고 templates/penpot-master-prompt.md를 현재 계약에 맞게 사용한다.
6. Godot 비전투 UI는 `ForestArenaResources` 논리 ID를 통해 리소스를 읽고 품질 경로를 하드코딩하지 않는다. UI 텍스트는 네이티브 텍스트로 유지한다.
7. Penpot 설계와 Godot 구현을 구분하며 외부 파일을 실제로 수정하지 않았으면 완료로 보고하지 않는다.

## 산출물과 검증

- _workspace/<topic>/02_ui.md와 씬·표현 계약.
- 멀티터치, 손가락 이탈, 포커스 손실, 카메라 안정성과 HUD 겹침을 검사한다.
- Penpot 작업은 24개 화면, 1920×1080 프레임, 컴포넌트 인스턴스, `IMG/*` 매핑과 `MISSING ASSETS` 목록을 감사한다.
- 리소스 또는 이를 소비하는 UI 변경 뒤 `python tools/forest_arena/verify_godot_resources.py --project-root .`를 실행한다.

## 참조

- 비전투 Penpot 절차: references/penpot-workflow.md
- 재사용 제작 프롬프트: templates/penpot-master-prompt.md
