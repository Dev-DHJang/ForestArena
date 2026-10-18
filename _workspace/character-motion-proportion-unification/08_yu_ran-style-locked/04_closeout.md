# 유란 제작 상태

승인·게임 반영 및 검사 완료 — 기존 idle 1종과 새29종, 합계30종.

- 2026-10-17 사용자 “승인한다.”로 새29종을 승인했다. `approval-all-30.json`에 정확한 승인 파일을 고정하고 승인128px 셀을 추가 확대·축소 없이 게임용 시트로 옮겼다.
- `07_before_install/`에 이전 PNG30개와 manifest를 보존했다. 전후 해시는 `08_install_receipt.json`, 검사 증적은 `03_qa_installed_r01.md`다.
- 현재 누적 검사는 `../install_approved_yu_ran.py --check`다. 승인90종의1,440셀, 자현30종·모든 SpriteFrames·콘셉트·전투 파일 및 나비 호환 PNG2개 보존을 확인한다. 과거 두 캐릭터까지만 반영됐던 검사와 시작 기준은 덮어쓰지 않는다.
- 반영 후 `./scripts/verify.sh`가 종료 코드0과 `Forest Arena verification passed.`로 완료했다. 출력은 `verify-installed-2026-10-17.log`에 있다. 문서·Godot 리소스 검사, 동결 검토판 재검사도 통과했다. Android 실제 기기 검증과 원격 Git 작업은 수행하지 않았다.
- 아래의 승인 대기·미반영 설명은 제작 당시 이력이며 현재 승인을 취소한다는 뜻이 아니다.

- `01_style_reference/selection.json`에 승인 idle 원본과 그 원본에서만 파생한 참조 2개를 고정했다. 내장 이미지 생성 도구로 모션마다 따로 생성했고, 같은 결과 하나씩만 참조해 배경을 제거했다. 프롬프트는 `generation-prompts-r01.json`, 요청·결과는 `02_drafts/`, `03_alpha/`에 있다.
- 중단 당시 완료된 10개 생성 결과를 찾아 보존했다. 저장 기록이 없던 6개는 원본·저장 이미지의 해시 또는 실제 동작을 대조해 연결했고 복구 표시를 남겼다. 기존 승인 이미지는 재생성하지 않았다.
- `04_review/`에 30개의 4×4 투명 시트, 각각의 128px 미리보기·16프레임 GIF, 전체 비교판, 머리 측정 안내판, 8개 전체 포즈 비교판과 `index.html`을 만들었다. 실제 크기·alpha·배율·원본/셀/검토 해시와 원래 FPS·반복 설정은 `30-motion-report.json`에 있다.
- 자동 검사 `YU_RAN_STYLE_LOCK_STRUCTURAL_R01`과 수동 확인 `YU_RAN_STYLE_LOCK_REVIEW_R01`을 완료했다. 30시트/480셀, 16개 실제 자세, 여백·우향·전신·그림체·귀/꼬리/리본·작은 크기 가독성을 확인했다. 수치 범위와 한계는 `03_qa_r01.md`에 있다.
- `pending-review-29.json`으로 새 29종의 정확한 검토 대상을 고정했다. 이 승인이 끝나기 전 게임용 PNG·manifest·SpriteFrames를 변경하지 않는다. 기존 idle 해시는 앞선 승인과 같다.
- 로컬 검토 서버 `http://127.0.0.1:8768/index.html`에서 GIF 30개가 모두 128px로 로드되는지 확인했다. 전체 비교판이 있는 실제 브라우저 화면을 `04_review/browser-preview.jpg`에 보존했다. 다른 서버는 종료하거나 변경하지 않았다.
- 묘령31·나비29 승인 이미지, 자현·유란 기존60종, 모든 SpriteFrames·콘셉트·전투 파일과 manifest는 `../install_approved_nabi.py --check`로 보존을 확인했다.
- 문서 검사, Godot 리소스346개 검사와 `./scripts/verify.sh` 전체 통과. 전체 출력은 `verify-project-2026-10-17.log`다.
- Android 실제 기기 검증과 원격 Git 작업은 수행하지 않았다. 전체90종의 승인·게임 반영 완료를 뜻하지 않는다. 다음은 유란 새29종 승인이다.
