# 목도리 굴곡·실제 화면 촬영 경로 독립 검토 r03

2026-10-24. 담당: motion_code_review. r02 이후의 새 held-special 굴곡과 raw RGBA 촬영/보관 경로를 독립 대조했다. 이 기록의 판정은 **코드 경계와 기록된 촬영 자료의 재현성 pass**다. 새 원화/회복 모션의 시각 품질 pass를 대신하지 않는다. 프로덕션·후보·촬영 자료를 수정하거나 삭제하지 않았다.

## 코드 경계

- `cloth_center()`는 기존 Bezier 중심선에 `sin(t*PI)`로 양 끝에서 사라지는 파형을 더한다. 실제 grip과 tip은 유지되며 내부 중심선과 그 접선만 굽힌다. 반전 때 파형의 기준축도 반전된다. 셀 좌표/표시 위치를 읽지만 전투 값이나 공격 시간을 쓰지 않는다.
- `wave_strength=14`, `flat_end=true`를 넘기는 곳은 `scarf_hand`가 있는 새 특수기의 한 가닥 경로 한 곳뿐이다. 손 좌표가 없는 기존 특수기·공중 강·일반 목도리 공격 호출은 기본값 `wave_strength=0`, `flat_end=false`를 사용한다. 이때 중심선 식과 끝 폭을 줄이는 식은 이전과 같다.
- FighterController와 LocalPresentation의 SHA는 r02와 같다. 초기화 신호·공격 프레임 선택·전투 snapshot/LAN 형식에 이번 굴곡 수정의 추가 변경은 없다.

직접 실행한 `qa/code-r03/vfx.log`는 **PASS**, `qa/code-r03/lifecycle.log`는 **430개 PASS**다. 고정 끝·굴곡·반전의 새 검사를 읽고 기존 특수기 분기/인자 기본값도 대조했다. 이 수치가 실제 옷감처럼 자연스럽게 보인다는 증거는 아니다.

## 실제 입력과 raw 화면의 범위

`render-live.gd`는 실제 main.tscn, MatchController, 지형, 전투 규칙과 CombatIntent를 사용한다. 자동 physics 호출을 끄고 `step_fixed_tick(false)`를 틱마다 한 번 실행한다. 준비/판정/회복 상태를 임의로 설정하는 촬영이 아니다. 각 틱의 의도 입력과 두 파이터의 snapshot·표시 프레임을 기록하며, 표시 처리 전후 snapshot 불변을 비교한다.

시작 배치, 지정한 장면 입력, 촬영용 카메라, 후보의 프로세스 한정 연결은 시험 조건이다. OS 포커스/중단 알림은 이전 검토와 동일하게 제외하고 보고서에 `platform_lifecycle_ignored_for_capture=true`, `android_device_test=false`를 남긴다. 실제 Android 생명주기나 사용자 플레이 결과로 주장할 수 없다.

각 캡처 시점에 표시를 갱신하고 `queue_redraw`한 뒤 `process_frame`을 기다려 `RenderingServer.force_draw(false)`를 호출한다. 화면을 그린 결과를 viewport에서 얻어1280×720 RGBA8로 저장한다. 이것은 배경 창의 frame_post_draw 대기 문제를 피하는 화면 출력 경로이며 전투 틱 수나 입력을 바꾸지 않는다. 실시간 성능/FPS 측정 자료로 사용해서는 안 된다. 검사한 자료는 capture_stride=1이라 모든 시뮬레이션 틱에 한 장의 화면이 있다.

아래 세 보고서를 직접 읽어 오류0, 매 틱 snapshot 불변, 전체 상태 수, 크기, 시작/끝 고정 소스와 현재 파일 해시의 일치를 대조했다.

| 자료 | 실제 장면 | 틱/화면 | 내부 검사 |
| --- | --- | --- | --- |
| `qa/live-normal-r03/state-report.json` | 자현 특수 일반1개 | 120 | 728 |
| `qa/live-mirror-small-r03/state-report.json` | 자현 특수 반전·소형1개 | 120 | 728 |
| `qa/live-all-normal-r05/state-report.json` | 두 캐릭터 공격·이동14개 | 1764 | 10701 |

마지막 자료는26개 항목의 공용 후보 목록을 읽었지만, 이14장면에서 실제 표시된 목록 항목은 **17개**다. 자현 death/guard/ring_out/spawn, 나비 death/guard/launch/ring_out/spawn의9개는 이 공격·이동 촬영에 나타나지 않는다. 이 자료만으로26개 전체 검사를 주장하면 안 된다. 별도 상태 전환 촬영 자료와 구분해야 한다. 두 실제 파이터에서 총27종의 motion ID가 관찰되는 수치에는 기존/pilot 그림도 포함된다.

## 원본 raw 보관과 독립 복원

정확한 보관 코드 경로는 `archive-raw.py`다. 완료된 보고서, 실제 고정 틱, capture_stride=1, raw 전체 바이트 수를 확인한다. raw의 각 RGBA frame MD5와 lossless MKV를 다시 RGBA로 읽은 모든 frame MD5가 같아야 한다. 그 뒤에만 receipt를 먼저 쓰고 선택 옵션으로 **해당 raw 파일만** 지운다. RGB lossless 압축에서 alpha를 보존하지 못하는 화면이면 RGBA 비교가 실패하므로 삭제 전에 멈춘다. MP4는 별도 미리보기이며 원본 복원 증거는 MKV다.

보고서의 pass 문구만 믿지 않고 본 담당자의 읽기 전용 `qa/code-r03/verify-archives.py`로 위 세 자료의 MKV **16개·2004프레임 전체**를 다시 디코딩했다. 다음을 모두 직접 확인했다.

- receipt가 가리키는 state-report SHA와 실제 보고서 일치.
- 보관 MKV의 SHA 일치.
- 모든 프레임의 RGBA MD5 일치.
- 복원된 전체 raw 바이트 수와 SHA256이 삭제 전 기록과 일치.

결과는 `qa/code-r03/archive-decode.log/json`에 있다. 검사 코드는 자료를 읽기만 하며 보관 파일과 receipt를 쓰거나 지우지 않는다. 일부 사진 추출이나 손실 MP4 비교로 대신하지 않았다.

## 고정한 검토 대상과 남은 범위

| 파일 | SHA256 |
| --- | --- |
| `scripts/fighter_attack_effects.gd` | `2c1b674a84788e1ee675142c11165cd6890f8c0f3818d817be35f399c31641f2` |
| `tests/two_fighter_vfx.gd` | `4eb56ec2e0ba81eed630ca1590926ccec5306e32d7a8fc24ebbb15fbb7743ed6` |
| `_workspace/ja-scarf-barrage-v1/render-live.gd` | `1fe944640584c3db9c4b0af9c318f5a6cd96e4ac762669f1a79cdcc4306a4183` |

이 범위에서 추가 코드 경계 문제는 발견하지 않았다. 검토 중 전체 `verify-r03.log`는 아직 마지막 통과 문구가 없어 이 기록에서 전체 검사 완료를 주장하지 않는다. 전체 반전 촬영도 이 기록의 확인 범위에 넣지 않았다.

별도 시각 QA가 **회복 초기에 긴 천이 아래를 다시 공격하는 것처럼 보임**을 발견했다는 전달을 받았다. 이는 이 코드 경계 검사로 무효화되지 않는다. root가 회복 축소/마지막 판정 방향 유지로 수정할 예정이므로 이 기록은 위 해시의 r03 관찰로 고정하고, 후속 diff·새 촬영의 재검토를 별도로 해야 한다. 모션별 사용자 승인과 실제 Android 검사는 여전히 별도다.
