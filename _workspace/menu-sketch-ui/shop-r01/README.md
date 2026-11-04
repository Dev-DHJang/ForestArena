# MENU09 상점5종 검토 자료

2026-11-04. 이전 대표3종과 캐릭터·신기3종은 사용자 승인 완료다. 이번 상점5종 shop-r01은 검토 대기이며 나머지10종은 후속 제작한다.

- Penpot 편집 페이지: `Forest_Arena_UI / 26_MENU09_Shop`.
- 검토 시작: `MENU09 상점 r01` 흐름 또는 `shop-character-myo-ryung-light` 보드.
- [5종 연락표](exports/shop-review.png), `exports/*-1280.png`는 축소 미리보기다. `viewer-*.png`는 실제 새 뷰어 표시다.
- `02_ui.md`: 참조 대응·데이터 출처·경제 미정과 개발 전달 경계.
- `missing-assets.md`, `missing-assets-union.json`: 상점26개와 현재 제작11종의 합집합28개 미수록.
- `data-id-mapping.csv`, `image-mapping.csv`: 기존 ID와 승인 원본 대응.
- `03_qa_r01.md`: 독립 QA. `04_closeout.md`: 최종 결과·통합·되돌리기.

## 재검사

`python3 _workspace/menu-sketch-ui/shop-r01/check_spec.py`로21개 참조·승인 근거·안전 여백·조작 크기·목적지·미정 가격 가드를 확인한다. 실제 뷰어는 `viewer-checks.json`의109단계로 재현한다. `overlay` 필드는 대화창 표시를 뜻하며 `shop-loading`은 정적인 전체 보드 안의 대화창이다.

확인창은 본래 화면의 버튼에서 열어 닫기를 검사한다. 보드 목록에서 확인창만 단독으로 열면 원래 화면이 없으므로 닫기 복귀 검사가 아니다. 보드 선택창은 선택 후에도 열려 있을 수 있어 오른쪽 위 닫기로 닫는다.

플러그인을 다시 연결했을 때는 이전 원본 ID를 복구한 다음 `bootstrap.py`와 `sync.py`로 이번 묶음의 명세·미디어·컴포넌트를 읽힌다. 이미 같은 키와 해시가 있는 보드는 재사용한다. 승인된 다른 페이지를 재생성하거나 다른 버전 보드를 자동 덮어쓰지 않는다.

긴 일괄 작업은 로컬 MCP의30초 제한을 넘을 수 있다. 이번에는 시간 초과 뒤 실제 키·완료 해시를 먼저 확인해 완료 보드를 다시 만들지 않았다. `make-wide.js`는 기존 편집 요소를 가운데로 옮겨20:9 비교를 구성한다. `wire-one.js`는 한 보드씩 연결한다. 현재 Penpot에서 `close-overlay`의 선택적 destination은 생략해야 검증을 통과하므로 정식 API의 생략 가능한 형식을 사용했다.

이미지 출력은 정식 `board.export`다. `export-selection.json`의19개를 선별하고 전체73개 네이티브와 실제 확인창 합성 화면을 함께 검사한다. 출력·해시·크기 목록은 `export-index.json`이다. 전체 게임 검사는 이미 통과했으며 실제 Android·경제·결제·게임 UI 개발 승인을 대신하지 않는다.

## 후속 수정

2026-11-04 캐릭터 목록 우선 수정은 [shop-r02](../shop-r02/README.md)가 현재 기준이다. 이 폴더는 변경 전 명세·PNG·리비전1010의 이력이다.
