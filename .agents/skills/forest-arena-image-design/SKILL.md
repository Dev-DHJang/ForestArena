---
name: forest-arena-image-design
description: 작은 Android 화면용 독창적 Forest Arena 콘셉트·초상화·아이콘·UI 이미지·배경을 제작한다.
---

# Forest Arena 이미지 디자인

## 사용 시점

- 콘셉트, 3등신 턴어라운드, 초상화, 아이콘, UI 이미지와 배경 원화에 사용한다.
- 신규 플레이어·전투 캐릭터의 최초 콘셉트, 사용자 승인과 자산 등록은 forest-arena-character-design이 소유한다. 승인된 캐릭터의 초상화·아이콘 등 후속 정적 이미지는 이 스킬이 소유한다.
- 프레임 조립, UI 배치와 전투 판정에는 사용하지 않는다.

## 필수 입력

- 현재 Phase, docs/content/art-and-audio.md, 용도·크기·카메라와 아트 방향.
- 캐릭터·직업·장신구 ID, 원본성·라이선스 조건과 소비자.
- 승인 캐릭터를 표현하면 `docs/contracts/character-appearance-v01.json`의 해당 외형 항목.
- 비전투 UI 이미지면 assets/ui/asset-requirements.csv의 정확한 슬롯·출력 경로·상태·승인 의존성.

## 작업 흐름

1. 플레이스홀더와 수직 슬라이스 품질을 구분한다.
2. 승인 캐릭터는 외형 계약의 필수·각도 한정·금지 요소를 지키면서 최대 줌아웃의 종별 실루엣, 공격 포즈와 배경 대비를 우선한다.
3. 제3자 IP, 상표와 특정 작가 스타일을 복제하지 않는다.
4. 원본·후편집·출처와 런타임 crop·alpha·색상 규칙을 기록한다.
5. UI 배치는 templates/ui-image-batch-prompt.md를 사용하되 `character-approval-required` 행은 생성하지 않는다.
6. Splash는 캐릭터 없이 만들고 장신구에는 희귀도·등급 단서를 넣지 않는다.

## 산출물과 검증

- _workspace/<topic>/02_image.md와 자산 기록·소비 규격.
- 권리, 해상도, 투명도, 실루엣과 실제 화면 가독성을 확인한다.
- 생성한 파일만 manifest 상태를 갱신하며 누락 파일은 `IMG/*` 플레이스홀더와 `MISSING ASSETS` 기록으로 인수인계한다.

## 참조

- 비전투 UI 이미지 배치 프롬프트: templates/ui-image-batch-prompt.md
