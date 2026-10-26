# 실제 LAN 사진 검사 준비 — 독립 검토 r03

판정: **PASS (두 변경의 실행 준비 범위)**. 제품·후보·manifest 변경 없이 fixture의 처리 순서와 방향 입력 절차만 검토했다. 실제 LAN·GUI·Godot·포트를 실행하지 않았다. 실제 사진과 네 release 자세의 표시 성공은 새 촬영 결과로 따로 판정한다.

## 실패 자료와 변경 범위

이전 `lan-launch-release-capture-r01/ja-hyun-normal/normal-report.json`은 2,672검사에서 FIX다. 오류는 post-draw의 픽셀/자세/수신상태 불일치 224건, facing 대기 시간 초과 1건, release 네 자세 순서 미충족 2건, 방향 불일치 8건이다. 두 클라이언트의 release 기록은 각각 `[12,12,14,15]`로 F13이 없다. 이 실패는 보존하며 r03 준비 통과로 대체하지 않는다.

검토한 두 변경:

1. `SceneTree._process`에서 하던 표시 갱신을 `render_step(delta)`로 옮겼다. 새 Node relay의 `process_priority=10000`은 기본값 0인 두 `LanMatchClient`의 `_process` 소켓 poll·snapshot 적용 뒤에 실행된다. relay는 전달받은 실제 delta를 한 번 호출한다. 기존 표시 계산 본문은 함수 이름·반환형·return 표현만 달라졌고, delta 축적·clock 계산은 같다. 수신을 미루거나 snapshot을 강제 수정하는 코드가 없다.
2. 양 클라이언트가 두 파이터의 SPAWN 종료·접지를 관찰한 뒤 이동한다. 각 MOVE RELEASE 뒤에는 당시 양 수신 tick의 최댓값보다 최소 2tick 뒤인 snapshot을 양쪽 모두 받아야 다음 PRESS로 진행한다. 방향 확인도 양쪽의 새 tick·facing 일치를 요구한다. host 재접근 뒤 RELEASE와 +2tick 확인을 마친 뒤에만 heavy를 보낸다. 각 대기 실패는 `natural_scenario()`에서 즉시 false로 반환하므로 다음 방향 입력이나 heavy로 계속하지 않는다. 접속·join 실패도 다음 단계로 진행하지 않는다.

코드 순서 검토는 root가 제시한 두 원인에 대응한다. 실제 Godot 그리기 시점에서 수신 상태가 일치하는지와 실제 delta에서 F13을 포함한 네 자세가 표시되는지는 이 정적 검토가 증명하지 않는다.

## 독립 소스 대조

`check-final-preparation-r03.py`를 읽기 전용으로 실행해 `final-preparation-r03-proof.json`에 기록했다.

- 현재 pin **2,828개**의 SHA가 모두 일치했다. r02와 공통인 **2,825개** 소스 해시는 모두 같다.
- r02 runner/client 두 경로를 r03 경로로 교체하고 relay 파일 한 개를 추가했다. runner 본문은 `render-relay.gd`를 고정 목록에 넣는 한 줄만 달라졌다. Python AST 문법도 정상이다.
- `transform_numbers`, `marker_bytes`, `on_sprite_draw`, `decoded_marker`, `on_frame_post_draw`의 5개 본문과 출력 폴더 guard는 r02와 같다.
- r02 소스 3개와 실패 r01의 보고서·로그 3개로 이루어진 생산자의 보존 목록 6개는 현재 SHA와 모두 일치했다.
- 생산자의 `check-only-r01.log`에는 오류가 없다. 이번 독립 회차에서 Godot 검사를 재실행하지 않았다.

최종 client SHA는 `0d7ea536f90eed30a9145de637e14281a25dad5b8ce67867b6574f0f013f5544`, relay SHA는 `9241fb72fd3fd1a4fce5a97232c5ca4aa7988ed34ad1d4ed721c23bf6297fb7f`다. runner와 전체 pin 파일 SHA는 proof JSON에 함께 기록했다.

기존 GPU probe는 공유 정적 helper 3개와 별도 wrapper 실행 자료다. LAN callback 두 개가 이번 r03에서 실행됐다는 뜻으로 확장하지 않았다. 실제 앱 HUD 영상·모션 품질·Android 통과도 주장하지 않는다.
