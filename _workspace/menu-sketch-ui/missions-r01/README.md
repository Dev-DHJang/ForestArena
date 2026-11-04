# 미션·출석·업적 검토 자료

2026-11-04. 상점 shop-r02는 사용자 승인 완료다. 새 미션·출석·업적3종 missions-r01은 검토 대기이며 남은 생활 메뉴4종·대전 준비3종은 후속 제작한다. 실제 개발은 하지 않았다.

- [Penpot 검토 시작](https://design.penpot.app/?screen=viewer&file-id=d8ac01df-6646-81d2-8008-a3696fea940e&page-id=e7a04c12-8c16-8028-8008-e478bacd52ea&section=interactions&frame-id=e7a04c12-8c16-8028-8008-e478c6d677b4&index=20&zoom=fit): 일일 미션에서 시작한다.
- [3종 미리보기](exports/missions-review.png), [실제 뷰어](exports/viewer-daily-final.png), `*-1280.png`, `*-wide.png`를 함께 확인한다.
- 편집 원본은 `Forest_Arena_UI / 27_MENU09_Missions`, 흐름은 `MENU09 미션·출석·업적 r01`이다. 지원 상태는 `mission-handoff`의 버튼으로 연다.
- `02_ui.md`: 참조04·05·13 대응, 기존7개 기록 ID와 연결 경계, 출석·수집·기술의 미정 항목.
- `03_qa_r01.md`, `native-audit.json`, `viewer-checks.json`: 독립 검토·실제 요소·뷰어 이동 검사.
- `missing-assets.md`, `image-mapping.csv`, `asset-audit.json`: 새 필수 미수록0개, 기존 미수록28개 유지, 승인 이미지17곳 재사용.
- `04_closeout.md`: 승인·검사·원격 통합·되돌리기 기록.

일일/주간·누적 대전 기록은 기존 기능과 대응한다. 현재 보상 지급은 없다. 출석28칸은 배치 예시이며 기간·집계·보상은 미정이다. 업적은 손그림의 대전·수집·기술3분류를 유지하고 수집·기술은 규칙 미정 상태다. UI 승인과 새 경제·캐릭터 활성화·실제 개발 승인을 구분한다.

## 재검사와 복구

`python3 _workspace/menu-sketch-ui/missions-r01/check_spec.py`로21개 명세·7개 실제 ID·여백·터치·목적지·로딩 배경을 검사한다. 실제 이동은 `viewer-checks.json`의 기록을 따른다. 확인창은 원래 화면의 버튼에서 열어 닫기를 확인한다. 보드 선택창은 보드를 고른 후 오른쪽 위 닫기로 닫는다.

로컬 공식 MCP가 연결된 올바른 파일을 확인한 뒤 `setup.py`로 도우미와 명세를 읽힌다. `make.py`는 이미 완료 해시가 같은 보드를 재사용한다. 긴 생성이 제한을 넘었을 때는 실제 키·완료 해시를 먼저 확인하고 `resume.py`의 완성 보드 재사용과 작은 요소 묶음 생성을 적용한다. 다른 승인 페이지를 재생성하거나 파일 전체를 복원하지 않는다.

연결은 `wire.py`와 `name-flows.js`로 구성한다. 현재 앱은 연결에서 시작 흐름을 자동 생성하므로 만들어진 흐름을 이름 붙여 재사용한다. 편집기에서 한글 배치를 표시하고 저장한 뒤 새 뷰어에서 다시 확인한다. 데이터상 글자가 있어도 실제 표시가 누락되면 통과로 기록하지 않는다.

PNG43개는 네이티브21·축소3·연락표1·실제 뷰어18개다. 내보내기는 정식 `board.export`이며 해시·크기·출처는 `export-index.json`에 있다. 전체 게임 검사와 Android 실기기 확인은 Penpot 검사와 별도다.
