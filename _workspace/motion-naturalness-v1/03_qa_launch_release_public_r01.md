# 날림 종료 공개 Godot 검사 독립 QA r01

담당: `qa /root/afterimage_final_r09`, 2026-10-26. **pass — 공개 검사와 verify 연결의 코드 범위**. 제품·검사·원화·manifest는 수정하지 않았다.

`tests/launch_release_presentation.gd`, `scripts/verify.sh`의 호출1줄과 `scripts/launch_release_clock.gd`, `scripts/local_fighter_presentation.gd`를 직접 읽었다. 공개 helper는 독립30,906검사를 통과한 r04 helper와 byte가 같다. 공개 presentation도 r04의 preload 경로와 주석1줄만 정규화하면 완전히 같다. 그 비교 결과와 현재 해시는 `qa/launch-release-public-independent-r01/result.json`에 보존했다.

공개 검사는 workspace 경로를0개 참조하고 실제 승인 `animation-runtime`의 자현 launch와16프레임 SpriteFrames를 읽는다. 그림 SHA와 같은 승인 리소스인지를 검사한다. 선택 표시 쌍은 각 presentation 인스턴스의 복제 Dictionary에만 추가하며 PNG나 실제 등록 JSON을 변경하지 않는다. 실제 승인 launch PNG와 manifest 및 코드 해시가 실행 전후 같은지도 별도로 대조했다.

프로세스 ID가 붙은 `user://launch-release-<PID>.json`에 저장·재로딩하여 float 숫자임을 확인하고 즉시 삭제한다. 테스트 자체가 삭제를 검사하며, 독립 실행 전후 실제 Godot 사용자 폴더의 `launch-release-*.json` 잔여 목록과 byte 해시도 같았다. 정상 종료 후 파일이 남지 않았다. 치명적 비정상 종료까지 자동 정리됨을 주장하지 않는다.

상태·남은 경직·입력 방향·예약 입력·activation·점프 가능 값의 표시 전후 불변, 반전·30/60/120FPS, F16 반복 금지, 새 공격·점프·피격·reset 중단, 중복 HIT 무시를 실행했다. 선택 필드가 없는 baseline은 현재 공개 Presentation의 별도 인스턴스다. 따라서 그 두 인스턴스 비교만으로 이전 제품 모든 동작과 같다고 증명한 것은 아니다. 이전 제품의 필드 없는 동작 보존은 앞선 r04 독립 검사와 이번 정규화 코드 동등성도 함께 근거로 쓴다.

실행:

```sh
godot --headless --path . --script res://tests/launch_release_presentation.gd
```

결과: **680검사 PASS, ERROR 없음**, `qa/launch-release-public-independent-r01/godot.log`. `verify.sh`에는 같은 명령1줄이 기존 표시 검사 뒤에 있고, 스크립트의 `set -eu`로 실패 시 중단된다. 전체 verify를 이번 역할에서 중복 실행하지 않았다.

이 검사는 새 이미지의 정식 등록이나 사용자 승인을 만들지 않는다. 실제 LAN 왕복·새 연결 픽셀 품질과 자연스러움·Android 기기 검사는 별도다.
