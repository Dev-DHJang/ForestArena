# 상점 캐릭터 목록 우선 수정 검토

2026-11-04. shop-r02는 **검토 대기**다. 상점5종의 최신 진입 동선을 반영했다. 기존 승인6종과 실제 개발 상태는 그대로다.

- [Penpot 검토](https://design.penpot.app/?screen=viewer&file-id=d8ac01df-6646-81d2-8008-a3696fea940e&page-id=e7a04c12-8c16-8028-8008-e43156c282df&section=interactions&frame-id=e7a04c12-8c16-8028-8008-e46852a05cb9&index=1&zoom=fit): 캐릭터 목록에서 시작한다.
- [목록·상세 미리보기](exports/character-flow-review.png): 캐릭터 카드를 선택하면 해당 상세로 이동하고 뒤로·캐릭터 탭은 목록으로 복귀한다.
- [실제 뷰어 화면](exports/viewer-character-list-final.png), `*-1280.png`, `*-wide.png`: 실제 표시·축소·20:9 비교.
- `02_ui.md`: 제작·참조 대응·개발 전달 경계. `03_qa_r01.md`: 독립 QA. `04_closeout.md`: 검사와 통합.
- 신기·재화 본문과 미수록 자산26개는 [이전 자료](../shop-r01/README.md)를 재사용한다. 다른 상점에서 캐릭터 탭을 누르면 새 목록으로 진입한다.

`python3 _workspace/menu-sketch-ui/shop-r02/check_spec.py`로75개 명세·4카드·상세20상태·기술/빠른 전환 보존을 확인한다. 실제 뷰어는 `viewer-checks.json`의26단계로 다시 검사한다. `native-audit.json`은 실제 편집 요소와 명세의 비교다.

재연결 뒤 `bootstrap.py`의 로컬 호출 도우미와 이전 묶음의 복구 절차를 사용한다. `sync.py`는 r02 명세를 읽힌다. `patch-one.js`는 소유한 검토 대기 보드만 변경한다. 전체 파일 복원·이전 승인 보드 재생성은 하지 않는다. 시간 초과 시 실제 키·완료 해시를 먼저 확인해 중복 생성을 방지한다.

PNG18개는 네이티브8·축소4·연락표1·실제 뷰어5다. `export-index.json`에 크기·해시·출처를 기록했다. 기존 shop-r01 미리보기는 당시 화면 이력으로 보존한다.

## 사용자 승인

2026-11-04 이 채팅에서 사용자가 “승인한다.”라고 답변했다. 위 검토 대기는 당시 전달 상태이며 현재 상점5종 shop-r02와 전달 상태·비교는 승인 완료다. 다음 [미션·출석·업적](../missions-r01/README.md)은 별도 검토 대기이며 실제 개발·경제 승인은 구분한다.
