# 묘령 승인·게임 반영 확인

2026-10-17 / `MYO_RYUNG_APPROVED_RUNTIME_INSTALL_R01`: pass.

- 사용자 승인: 앞선 3종과 2026-10-17 승인된 28종의 모든 검토 파일을 해시로 대조했다. `approval-all-31.json`에 정확한 대상을 기록했다. 승인 전의 보고서를 승인 후처럼 고쳐 쓰지 않았다.
- 이미지: 승인된 512×512의 16셀을 순서대로 2048×128에 옮겼다. RGBA/실제 alpha, 셀마다 여백 2px 이상, 16개의 다른 포즈, 모든 496셀 픽셀 일치를 확인했다. 승인 후 재생성·재색칠·크기 변경은 없다.
- 표시: 묘령 31종만 `presentation_scale=1.0`, `foot_pivot_y=124`다. 기존 ID·프레임 수·FPS·반복·파일 경로와 SpriteFrames 연결은 그대로다.
- 보존: 자현을 포함한 다른 캐릭터의 런타임 89종과 모든 SpriteFrames, 기존 콘셉트·전투 데이터, 묘령 외 manifest 항목을 시작 상태와 비교했다. 다른 기존 미커밋 작업은 건드리지 않았다.
- 복구: 기존 31종 PNG와 manifest를 `07_before_install/`에 먼저 복사했다. `08_install_receipt.json`에 전후 해시·파일 크기를 남겼다. 삭제한 자료는 없다.
- 재현: `python3 _workspace/character-motion-proportion-unification/install_approved_myo.py --check` 통과. 이 검사는 원래 기준 파일을 변경하지 않고 승인된 묘령 변경만 허용한다.
- 전체 `./scripts/verify.sh` 통과, 로그 `verify-installed-2026-10-17.log`. 문서 검사와 Godot 리소스 검사도 통과했다(346개 논리 ID, 품질별 차이 24개). 기존 종료 시 ObjectDB 경고가 있으나 검사는 실패하지 않았다.
- 메모리: 이미지 규격과 31장 RGBA8 디코딩 예산 32,505,856바이트는 이전과 같다. 이는 Android GPU 메모리·프레임 속도를 측정한 결과가 아니다.
- 한계: 실제 전투 창에서 31종을 모두 재생하는 수동 확인, 최대 줌아웃 실기기 가독성, Android 물리 기기 성능 검사는 미실행이다. 제작 시 전체 포즈 검토와 자동 로드/전투 재검사 결과를 기기 통과로 확대하지 않는다.
- 나비·유란의 미제작 모션을 승인 처리하거나 게임에 먼저 쓰지 않았다. 원격 commit/push/PR/병합은 승인 계획의 제외 범위다.
