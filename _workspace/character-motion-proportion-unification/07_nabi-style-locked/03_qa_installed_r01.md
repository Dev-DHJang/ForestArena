# 나비 승인 이미지 게임 반영 검사

2026-10-17 / `NABI_APPROVED_RUNTIME_INSTALL_R01`

- 사용자 “승인한다.”로 새 28종을 승인했다. 앞서 승인된 idle과 합친 29종은 `approval-all-29.json`에 검토 보고서·원본·파일 해시로 고정했다. 과거 검토 보고서의 미승인 표시는 당시 기록으로 보존했다.
- `install_approved_nabi.py --check` 통과. 29시트/464셀은 승인된 128px 검토 셀과 픽셀이 같다. 2048×128 RGBA, 표시 배율 1.0, 발 기준 124다. 추가 크기 조절은 없다.
- 덮어쓰기 전 나비 29종·이전 호환 PNG 2개·manifest를 `07_before_install/`에 보존했다. 이전 호환 PNG 2개도 승인된 대응 기본 연계와 같은 이미지로 맞췄다. 전후 SHA-256은 `08_install_receipt.json`에 있다.
- 묘령 31종은 승인 픽셀과 일치한다. 자현·유란의 60종, 전체 SpriteFrames, 콘셉트·전투 파일을 작업 시작 시점 그대로 보존했다. ID·FPS·반복·공개 API와 판정 수치는 변경하지 않았다.
- 이후 보존 검사는 묘령만 교체됐던 과거 검사 대신 `install_approved_nabi.py --check`를 사용한다. 이전 기준과 반영 기록은 덮어쓰지 않았다.
- 문서 검사와 Godot 리소스 346개 검사 통과. `./scripts/verify.sh`도 `Forest Arena verification passed.`로 완료했다. 전체 출력은 `verify-installed-2026-10-17.log`다. 종료 시 일부 기존 Godot ObjectDB 경고가 있으나 검사 실패는 없었다.
- Android 실제 기기 검증 없음. 원격 Git 작업 없음.
