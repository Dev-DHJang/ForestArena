# 승인된 25종 등록 — 독립 QA r01

판정: **PASS**. 현재 직접 사용자 승인에 묶인 자현 12종·나비 13종이 원 계획대로 등록됐고, 후속 메타데이터 정리와 실제 Godot 로딩까지 확인했다. 새 사용자 승인을 요구하지 않았다. 이 검사는 등록의 정확성과 실제 로딩을 확인하며, Android·실제 HUD·새 GPU 장면을 검사한 결과로 확대하지 않는다.

## 승인과 원래 설치

`remaining-user-motion-registration-approval-r10.json`은 2026-10-26 직접 사용자 메시지 “승인한다.”와 개별 25종의 PNG·후보 TRES·등록 TRES 해시를 담는다. 기존 승인 자현 `special_scarf_sweep`와 미래 모션은 범위 밖이다. `qa/approved-registration-r10/ready-plan.json`, `receipt.json`, 백업 receipt의 계획이 서로 동일하고, 기존 읽기 전용 계획 SHA `e66bfcf150d8b8c9aa1c174709aa5f4322ba6caffde351321566079d8c6baa88`에 묶였음을 독립 계산했다. catalog·scope·독립 최종 QA·targets 해시도 현재 파일과 승인 기록에 모두 일치한다.

메타데이터 정리 **전** 원 설치를 먼저 검사하고 `qa/approved-registration-independent-r01/initial-installed-manifest.json`과 `initial-installation-proof.json`에 보존했다. 원 manifest SHA는 `21a3cc9860104cf1d8f8478eb4db744ef9a23cfb9a3f52a91bf6ac898868eaf0`다.

- 계획의 **51개 출력**(새 PNG 25·기존 TRES 25·manifest 1) SHA가 모두 설치 파일과 일치했다. 바뀐 기존 파일의 백업은 계획의 before SHA와 일치했다.
- 새 PNG 25개는 독립 검토한 후보 PNG와 전체 파일 바이트가 같다. 기존 PNG 1,123개는 등록 전 실제 LAN 검사의 소스 목록과 전부 같다.
- TRES 25개는 각각 후보 TRES에서 PNG 참조 경로 한 군데만 등록 경로로 바꾼 바이트와 같다. `_workspace` 참조는 없다. frame count·순서·region·FPS·loop·표시 가중치를 설치 중에 다시 설계하지 않았다.
- manifest 130개 항목의 기존 asset ID 집합은 같고, 선택된 25종의 ID·`consumer_path`·TRES 경로는 기존과 같다. 타 **105개 항목은 deep-equal**이다. 선택된 항목의 직전 원본은 등록 이력에 남았다.
- `launch_release_frame_range/ticks`, `state_duration_ticks`, `landing_down_frame_range`, `state_hold_frame`, frame pivot·scale·anchor·phase 등 선택 표시 필드는 후보와 같다. 없는 필드를 임의로 추가하지 않았다.
- 기존 자현 특수기의 PNG·TRES는 별도 보존 SHA와 같다. 등록 전 소스 고정 2,828개 중 바뀐 것은 계획의 manifest와 TRES 25개뿐이며, 나머지 2,802개는 같다. 저장·LAN 메시지 버전 및 전투·서버·표현 코드를 변경한 사실은 없다.

## 후속 설명 필드 정리

원 계획은 자현 launch 후보의 top-level `status: unapproved-workspace-only`도 복사했다. 이 과거 단계 문구를 발견해 root에 알렸고, 원 설치 검증을 끝낸 뒤 root가 그 필드 하나만 제거했다. 현재 승인의 기준은 `motion_registration.approval_record`에 연결된 최신 직접 승인 기록이다. 제작 시점의 출처 설명인 `rights.status` 원문은 그대로 보존했다.

초기 manifest의 자현 launch에서 `status`를 한 번 제거한 문서와 현재 manifest가 deep-equal임을 독립 확인했다. 정리 후 SHA는 `0af4d840475beb3d85f7d3844e1a923d80437c3d1b561a0d12c30a27fd86a155`다. PNG·TRES 50개는 계속 원 계획 SHA와 같고, 승인·원 receipt·계획도 불변이다. `metadata-cleanup-proof.json`과 root의 `qa/approved-registration-r10/metadata-cleanup-r01.json`이 이 후속 차이를 분리 기록한다. 현재 manifest를 원 receipt의 초기 manifest와 같은 바이트라고 부르지 않는다.

## 실제 Godot 로딩과 효과 설정

import 완료 뒤 후보 테이블을 덮어쓰지 않는 새 독립 headless probe로 두 실제 `FighterController`와 공개 `local_fighter_presentation.gd`를 만들었다. 공개 manifest 탐색과 `_motions` 로딩이 등록된 TRES를 실제로 선택하는지 확인했다. 검토 전용 후보를 public presentation에 끼워 넣지 않았다.

| 시점 | 결과 | 검사 수 | 실제 import 프레임 |
| --- | --- | ---: | ---: |
| 초기 설치 manifest | pass / 종료 0 / 오류 0 | 2,232 | 416 |
| 한 필드 정리 후 manifest | pass / 종료 0 / 오류 0 | 2,256 | 416 |

25개 모션의 실제 import Texture를 Godot에서 읽고, 기존 검토에 사용한 import-parity 로더(투명 경계 보정 포함)의 각 128×128 RGBA와 **전체 416개 프레임 바이트를 비교**했다. 모두 같다. AtlasTexture의 region·margin·duration, 모션의 FPS·loop와 등록 PNG 경로도 맞는다. 원 PNG는 수정하지 않았다.

공개 presentation이 manifest의 실제 metadata를 그대로 읽는지 확인했고, `display_layout`을 거친 유효 frame anchor·공격 phase·launch release pair·down 범위도 후보와 같았다. 따라서 표시·효과가 읽는 설정을 등록 과정이 잃어버리지 않았다. 이는 ResourceLoader·설정 검사의 결과이며 공격 효과의 새 GPU 재생 장면을 봤다는 뜻은 아니다. runtime 전환 재촬영과 앱 전체 검사는 root의 별도 회차다.

독립 실행 자료는 `qa/approved-registration-independent-r01/`의 `runtime-load-probe.gd`, `runtime-load-proof.json`, 정리 후 `runtime-load-probe-cleaned.gd`, `runtime-load-proof-cleaned.json`과 각 로그에 있다. 새 probe의 차이는 출력 파일 이름과 유효 표시·효과 필드 대조 추가이며 원 probe 결과도 보존했다.

## 범위와 마무리

제품 코드·원화·후보·설치 파일·생산자 계획/승인/receipt는 이 독립 역할이 수정하지 않았다. 독립 증거와 보고서만 만들었다. 이미 승인된 그림의 출처 문구 보존과 현재 승인 기록의 연결을 구분했고, 남은 등록 fix/blocked는 없다. 실제 Android 기기의 가독성·조작·중단/복귀는 여전히 별도 수동 재검사다.
