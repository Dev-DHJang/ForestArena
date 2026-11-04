# MENU09 손그림 기반 UI 검토 자료

2026-11-04. 현재21종 중14종을 설계했다. 대표3장 r01·캐릭터·신기3종 collection-r01·상점5종 shop-r02는 사용자 승인 완료다. 미션·출석·업적3종 missions-r01은 검토 대기이며 나머지7종은 후속 제작한다. Godot 메뉴·API·저장·게임 규칙 변경은 없다.

## 먼저 볼 자료

- `exports/representative-review.png`: 대표3장 연락표.
- `exports/viewer-*-reloaded.png`: 새 Penpot 뷰어에서 실제 표시한 화면.
- `approval-register.md`, `screen-register.json`:21종 대응·현재 승인 상태.
- `02_ui.md`, `03_qa_r01.md`, `04_closeout.md`: 제작·독립 QA·진행과 통합 기록.
- `references/`: 사용자 제공21개 JPEG의 바이트 보존 사본. 출처와 SHA-256은 화면 등록표에 있다.

## Penpot

편집 원본은 Forest_Arena_UI의23_MENU09_Review, 전달 안내는24_MENU09_Handoff에 있다. 모든 글자와 버튼·도표는 편집 가능하다. `MENU09 대표안 r01` 흐름으로 실제 이동을 검토한다.

API로 화면을 추가한 뒤에는 편집기에서 해당 페이지를 실제 표시하고 글자 배치 계산을 마친 다음 저장해야 한다. 이번에는 새 뷰어 탭을 열어19단계·실제 한글 표시를 다시 확인했다. 보기 전용 화면의 글자 누락을 데이터 존재 검사만으로 통과시키지 않는다.

1920 PNG는 대표·지원상태14종,20:9비교3종은 실제2400×1080이다. `*-wide-1920.png`의1920은 설계 기준을 뜻하며 실제 크기는export-index.json에 기록했다. 대표1280×720은 실제 PNG의 LANCZOS 축소본이다.

## 재검사

```sh
python3 _workspace/menu-sketch-ui/check_spec.py
node _workspace/menu-sketch-ui/check_preservation_metrics.cjs
```

첫 검사는21개 참조·해시·안전여백·조작크기·이동과 명시적 승인 근거를 확인한다. 두 번째는 실제 Penpot을 변경하지 않고6개 기존 화면의 텍스트 높이 캐시 차이를 검증한다. 제작 전 원본1586개·공식24화면·컴포넌트586개 보존 근거는preservation-summary.json과 개별 원시 기록에 있다.

`baseline.js`와inventory는 작업 시작 전 원본 조사 기록이다. 기존MENU09가 있는 상태에서 시작 전 기준을 다시 캡처해 덮어쓰지 않는다. `scene-spec.json`이 새 설계 명세이며 `build_spec.py`로 재생성한다. Penpot 기록과 현재 화면을 확인한 뒤 필요한 새 버전만 제작하고, 승인된 프레임을 자동 덮어쓰지 않는다.

캐릭터·신기 후속 묶음은 [collection-r01/02_ui.md](collection-r01/02_ui.md)와 해당 PNG·QA 기록에서 검토한다. 대표 승인 기록은 `approval-register.md`에 있으며 실제 개발 착수와 구분한다.

## 최신 검토 묶음

미션·출석·업적3종의 최신 검토 자료는 [missions-r01/README.md](missions-r01/README.md)와 [3종 미리보기](missions-r01/exports/missions-review.png)다. 최신 검토 안내는 Penpot의27_MENU09_Missions / mission-handoff다. 기존 승인 페이지와 제작 당시 안내·PNG는 이력으로 보존한다. 전체 승인 상태의 현재 기준은 `screen-register.json`과 `approval-register.md`다.
