# 유란 승인 이미지 게임 반영 검사

2026-10-17 / `YU_RAN_APPROVED_RUNTIME_INSTALL_R01`

- 사용자 “승인한다.”로 새 29종을 승인했다. 기존 승인 idle을 합친 30종은 `approval-all-30.json`에 보고서·검토 파일·선택 원본의 해시로 고정했다. 과거 보고서의 미승인 표시는 당시 이력이며 수정하지 않는다.
- `install_approved_yu_ran.py --check`: pass. 유란 30시트/480셀과 승인 검토 셀의 픽셀이 정확히 같다. 2048×128 RGBA·16셀, 표시 배율1.0·발 기준124이며 승인 뒤 추가 크기 조절은 없다.
- 모든 게임용 시트를 먼저 별도 준비하고, 덮어쓰기 전 기존 유란 PNG30개와 manifest를 `07_before_install/`에 백업했다. `08_install_receipt.json`에 전후 SHA-256과 파일 크기를 기록했다. 원본 PNG 합계는 4,554,757bytes, 새 PNG는 8,329,879bytes다. 비압축 RGBA 예산은 30MiB로 같다.
- 최종 누적 검사 `FINAL90 INSTALL`은 묘령31·나비29·유란30의 승인 셀1,440개를 확인했다. 기존 자현30종, 전체120개 SpriteFrames, 콘셉트·전투 파일과 나비 호환 PNG2개도 보존됐다. 각 캐릭터 반영 전후 manifest·승인·백업 해시 연결도 검사했다.
- ID·FPS·반복·사용 경로·공개 API·AttackData·MoveSetData·전투 판정을 변경하지 않았다. 이 턴에서 바뀐 게임 자산은 승인 유란 PNG30개와 해당 manifest의 표시·제작·승인 기록뿐이다. 다른 미커밋 변경은 작업 시작 기준 그대로 보존했다.
- `verify_yu_ran_style_review.py` 재검사 통과. 동결 검토 파일은 그대로이며 현재 승인30/대기0, 게임 반영 상태는 별도 기술 검사 기록으로 구분했다.
- 문서·Godot 리소스346개 검사 통과. `./scripts/verify.sh`가 종료 코드0과 `Forest Arena verification passed.`로 완료했다. 전체 출력은 `verify-installed-2026-10-17.log`다. 일부 기존 Godot ObjectDB 종료 경고는 있으나 검사 실패는 없었다.
- Android 실제 기기 검증 없음. 메모리·성능 실측 통과를 뜻하지 않는다. 원격 Git 작업 없음.
