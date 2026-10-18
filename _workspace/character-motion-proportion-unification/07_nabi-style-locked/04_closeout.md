# 나비 제작 상태

승인·게임 반영 완료 — 승인된 idle 1종과 새 28종, 합계 29종.

- 2026-10-17 사용자 “승인한다.”로 새 28종을 승인했다. `approval-all-29.json`에 정확한 29종을 고정했고, 승인 검토 셀을 추가 확대·축소 없이 게임용 시트에 옮겼다.
- `07_before_install/`에 이전 29종·호환 PNG 2개·manifest를 백업했다. 전후 해시는 `08_install_receipt.json`, 반영 확인은 `03_qa_installed_r01.md`다.
- 현재 누적 검사는 `../install_approved_nabi.py --check`다. 묘령 31종과 나비 29종의 승인 픽셀, 다른 캐릭터·전투·SpriteFrames 보존을 확인한다.
- 아래 내용과 검토 보고서의 승인 대기 표시는 제작·검토 당시의 이력이며 현재 승인을 취소한다는 뜻이 아니다.

- 전체 29종의 4×4 투명 시트, 128px 미리보기, 16프레임 GIF, 전체 비교판과 검토 페이지는 `04_review/`에 있다. 현재 승인된 것은 기존 idle뿐이며 새 28종은 사용자 승인 대기다.
- 기록 도구 `../prepare_nabi_style.py`와 `generation-prompts-r01.json`에 고정 참조 및 동작 의도를 보존한다.
- 내장 생성 도구의 원본·배경 제거·한 가지 변경별 수정 이력을 남겼다. 선택한 결과의 크기/alpha/해시/배율/포즈 위치/FPS·반복은 `04_review/29-motion-report.json`이다. 실패 후보는 삭제하지 않고 원본 이력으로 남겼다.
- `NABI_STYLE_LOCK_STRUCTURAL_R01`에서 29시트·464셀 검사와 기존 승인 idle 보존을 확인했다. `NABI_STYLE_LOCK_REVIEW_R01`은 8개 전체 비교판을 확인했다. 측정 범위·수정 이력·한계는 `03_qa_r01.md`에 명시했다.
- `pending-review-28.json`으로 새 28종을 해시 고정했다. 다음 승인은 이 파일과 실제 검토 파일을 대조한다. 승인 전 나비 런타임/manifest 반영과 유란 전체 제작을 진행하지 않는다.
- 검토 전용 서버를 `127.0.0.1:8767`에 열고 내장 브라우저에서 GIF 29개 로드를 확인했다. 실제 상단 재생 표본을 확인했고 `04_review/browser-preview.jpg`를 저장했다. 기존 8765·8766 서버는 변경하지 않았다. 파일로도 `04_review/index.html`을 열 수 있다.
- 문서 검사, Godot 리소스 검사(논리 ID 346개, 품질별 차이 24개)와 `./scripts/verify.sh` 전체를 통과했다. 전체 출력은 `verify-project-2026-10-17.log`다.
- Android 실기기 검증 없음. 원격 Git 작업 없음.
