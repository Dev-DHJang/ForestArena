# 숲빛 UI 제작 마무리

## 결과

Forest_Arena_UI에 숲빛 유리·잎 장식 UI를 적용했다. 기존 SCR 24개와 CBT 8개, 추가 EXT 6개, 상태 STATE 12개로 편집 원본은 50개다. 로비·선택·전투의 20:9 비교 3개를 포함해 검토 PNG 53개를 내보냈다.

원본 SVG 87개와 투명 PNG 87개를 `assets/ui/forestlight-v01/`에 제작했다. Penpot 신규 컴포넌트는 벡터 87개와 조합 6개, 총 93개다. 기존 보관 22개를 포함한 라이브러리 전체는 115개다. 기존 화면 ID와 비전투 데이터 형식은 유지했다.

10_Prototype에는 50개 화면과 검토 목록 1개가 있으며, 실제 연결 248개의 목적지 오류는 0개다. 편집 가능한 원본과 클릭 검토용 PNG 프로토타입을 구분했다. 주요 오프라인 선택·전투·나가기 취소·결과·재시도 흐름은 보기 모드에서 직접 확인했다.

- [Penpot 프로토타입](https://design.penpot.app/#/view?file-id=d8ac01df-6646-81d2-8008-a3696fea940e&page-id=fa154361-0c45-804b-8008-a716ae2e1448&section=interactions&frame-id=5eab23a0-5a25-8021-8008-a985c54ba777&index=0)
- 제작 출처와 자산 설명: `02_image.md`, `assets/ui/forestlight-v01/manifest.json`.
- 좌표·앵커·실제 터치 영역: `02_ui.md`, `touch-layout.csv`.
- 검토 증거: `03_qa.md`, `exports/`, `geometry-audit.json`, `penpot-final-audit.json`.
- 이미지 매핑: `image-mapping.csv`, `missing-assets.json`.

## 미정·제한

기존 이미지 슬롯 61개 중 실제 파일 누락은 0개다. 자현 원화의 검은 배경은 유지했으며 별도 투명 컷아웃은 없다. 직업·경기장·Story 챕터의 확정 콘텐츠 원화는 미정이고 의미 아이콘·준비 중 표시를 사용한다.

AI 난이도, 추가 직업·챕터·경기장, 온라인 재연결·이탈 처리, 보상·가격·성장 정책은 제품 결정이 필요하다. 크기 85–110%와 투명도 60–100%는 설계 검토 범위다. 온라인·상점·성장 등은 미래 설계다.

이번 전투 버튼 배치는 기존 Godot 배치와 다른 제안이다. 이 작업에서 Godot 화면·입력 코드·저장 형식을 변경하지 않았다. 동시 입력·버튼 경계 이탈·앱 중단과 복귀·실제 카메라와 손가락 가림은 구현 후 Android 기기에서 검증한다.

## 검사

최초 실행에서 `./scripts/verify-docs.sh`, `./scripts/verify.sh`, `python3 tools/forest_arena/verify_godot_resources.py --project-root .` 모두 종료 코드 0으로 통과했고 각각 `verify-docs.log`, `verify.log`, `verify-resources.log`에 기록했다. 최신 `develop` 위로 재배치한 뒤 문서 검사와 리소스 검사를 다시 실행해 논리 자산 346개를 확인했다. 이것은 이번 신규 UI 자산 수와 다르다. 게임 기본 검사의 통과와 새 UI 시각 검토, 실제 Android 기기 검증은 서로 다른 결과다.
