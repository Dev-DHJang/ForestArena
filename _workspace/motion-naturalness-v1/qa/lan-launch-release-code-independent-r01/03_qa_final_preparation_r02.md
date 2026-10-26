# 실제 LAN 사진 검사 실행 준비 — 독립 검토 r02

판정: **PASS (실행 준비 범위만)**. `lan-launch-release-visual-r02`의 최종 출력 경계와 소스 고정을 읽기 전용으로 확인했다. 실제 LAN 연결, 두 LAN 그리기 callback 실행, 사진의 자연스러움, Android 기기 결과는 이 판정에 포함하지 않는다. 이번 독립 검토에서 GUI·Godot·소켓·포트를 실행하지 않았다.

## 최종 변경과 출력 경계

- 보존본 `pre-client-guard/client-fixture.gd`와 비교하면 변경 함수는 새 `safe_output_directory`와 이를 호출하는 `run`뿐이다.
- 클라이언트는 출력 파일을 열기 전에 기존의 정식 절대 경로, `simplify_path`와의 일치, 정확한 `_workspace/` 하위 경계, 기존 출력 폴더, 모든 상위 경로의 링크 여부를 확인한다. 기존 report/raw 파일·폴더·링크도 거부한다.
- runner는 기본·명시 출력 경로 모두 `resolve()`하고 `_workspace` 경계와 기존 출력 폴더를 거부한 다음 새 폴더를 만든다. 각 case 폴더 역시 새로 만든다. 이 정상 호출 경로에서 기존 PNG 디렉터리를 덮어쓰는 흐름은 없다.
- 이 회차는 추가 guard 경계 동작을 실행한 결과가 아니다. 최종 코드의 선행 검사와 원래의 새 출력 폴더 규칙을 검토한 결과다. 생산자의 check-only 로그는 종료 코드 0, 오류 문구 0으로 남아 있다. Python AST 문법 검사도 독립 수행했다.

## 소스 고정과 그리기 귀속

- 최종 `prepared-source-hashes.json`의 **2,827개** 파일 모두 현재 파일의 SHA-256과 일치했다.
- 과거 누락 6종인 `project.godot`, 두 서버 scene, 기본 loadout, 자현·나비 character Resource가 모두 포함된다. 공개 presentation과 `launch_release_clock.gd`도 포함된다.
- `assets`·`forest_arena` 전체 소스와 지정된 scripts/server/scenes 범위가 runner의 시작 전·종료 후 해시 비교 대상이다. 고정된 텍스트 Resource·GDScript·project 파일에서 추출한, 현재 존재하는 정적 `res://` 참조 중 고정 목록 밖 파일은 **0개**였다. 이는 정적 문자열 참조 검사이며 임의의 동적 경로 전체를 탐색했다는 뜻은 아니다.
- `transform_numbers`, `marker_bytes`, `on_sprite_draw`, `decoded_marker`, `on_frame_post_draw`의 다섯 함수 본문은 guard 이전 보존본과 각각 동일했다. sync/draw/post-draw의 시간·자세 귀속 로직을 이번 변경이 바꾸지 않았다.
- 기존 GPU probe의 실행 범위는 공유 정적 함수 3개와 probe 자체 draw/post-draw wrapper다. LAN의 `on_sprite_draw`·`on_frame_post_draw` 두 callback은 실제 LAN 촬영에서 새로 확인해야 한다. 소스 동일성 확인을 callback 실행 통과로 계산하지 않는다.

## 검토 파일 고정값

| 파일 | SHA-256 |
| --- | --- |
| `lan-launch-release-visual-r02/client-fixture.gd` | `b0df0475e91311d5fb5f17ae9e9c89f11ed50980ab6e80dfea1589e0dd133924` |
| `lan-launch-release-visual-r02/run.py` | `7cb7fded1732bdbd7a2b468e2860cf19a89f9846d1983f7f6fb7922cd7d00f45` |
| `lan-launch-release-visual-r02/prepared-source-hashes.json` | `b810038d05722c60cda3c199ebbb1bd289cc9c285c57e428cbd38336eedb192c` |

기존 2,752 marker 검사, 240 GPU PNG 픽셀 검사, archive mock 5건과 원본 자료는 이 폴더에 그대로 보존했다. 이들을 새 실제 LAN 사진 검사로 다시 이름 붙이지 않았다. 제품 코드·후보 이미지·manifest·생산자 fixture는 수정하지 않았다.
