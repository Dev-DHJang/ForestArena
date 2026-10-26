# LAN 실행 도구 r02 독립 QA

판정: **fix — 실패를 통과로 기록할 수 있는 두 조건이 남아 있다.** 기존 출력 보존과 지원 경로인 Python runner의 출력 범위 검사는 pass다. 별도로 실제 R03 소켓 자료는 아래 좁은 범위에서 유효함을 확인했다. 이 검토에서 기존 코드·보고서·출력은 수정하지 않았다.

## 실행 도구의 두 수정 항목

1. **[P2] 다른 사례 보고서를 통과시킴.** `run.py:81`의 `valid_report`는 status/errors/checks/presentation만 확인한다. 모의 하위 프로세스가 세 사례 모두 `mode="other-case"`인 JSON과 각 사례의 PASS 로그를 내면 runner가 종료 코드 0과 최종 pass를 쓴다. 보고서 `mode == mode`를 확인하고, 보고서 `catalog_sha256`도 이번 실행의 고정 후보 목록 해시와 비교해야 한다.
2. **[P2] 서버 오류를 최종 결과에서 제외함.** `run.py:82,95`는 client 로그만 확인한다. 서버 로그에 `SCRIPT ERROR: injected server fault`를 넣어도 client 보고서/로그가 pass이면 최종 pass가 된다. 서버 종료 뒤 해당 server 로그와 auth 로그의 SCRIPT ERROR/ERROR/Traceback 등 실패 표시도 최종 조건에 포함해야 한다. 이는 서버 오류를 실제 R03에서 발견했다는 뜻이 아니다.

별도 모의 시험 `independent-boundaries-r01.py`는 socket 생성과 subprocess 실행을 가짜 객체로 바꿨다. 실제 서버 포트를 사용하지 않았다. 17개 중 15개는 기대대로 동작했고 위 2개는 거부해야 할 사례를 통과시켜 전체 시험 종료 코드 1이다. `independent-boundaries-r01.json/.log`와 `mock-only-independent-*/MOCK_ONLY.txt`에 모의 시험임을 표시했다. 그 아래 자동 생성된 runner 보고서는 실제 LAN 결과가 아니다.

## 기존 출력과 출력 경계

- Python runner는 요청 경로를 `resolve()`한 뒤 `_workspace` 아래인지 확인한다. 이미 있는 출력 폴더는 파일 생성·소켓/프로세스 시작 전에 거부한다. 새 폴더 생성도 기존 폴더를 덮어쓰지 않는 `mkdir`이다.
- 자체 시험에서 기존 폴더/sentinel 보존, 작업 공간 밖 경로, 밖으로 향한 symlink 경로, res://가 아닌 presentation, `..` 이탈, 없는 presentation을 거부했다. 어떤 소켓/프로세스 호출도 시작하지 않았음을 함께 확인했다.
- root의 `no-clobber-selftest-r01.json`에서 기존 r02 출력 27개 before/after가 동일하고, 그 27개 현재 해시도 다시 계산해 모두 동일했다. 이것은 예전에 일부 덮어쓴 r01 원시 로그를 복구했다는 주장이 아니다. `lan-launch-release-r01/05_replay_superseded.md`의 정정은 그대로 보존했다.
- Godot fixture 자체의 DIR 확인은 문자열 `begins_with(workspace)`라 `..`/symlink 정규화를 하는 Python runner보다 약하다. 정식 runner는 이미 정규화한 경로만 전달하므로 지원 실행 경로의 이탈을 재현하지 않았다. fixture 직접 실행까지 독립 지원하려면 동일한 정규화 검사를 추가하는 편이 좋다.

## 실제 product R03 자료 독립 재검산

root가 실행한 `../lan-launch-release-product-r03/`를 별도로 읽었다. 이번 역할이 소켓 시험을 재실행한 것은 아니다.

| 사례 | 검사 수 | 직접 확인한 범위 |
|---|---:|---|
| natural | 1,357 | 실제 나비 강공격 HIT/LAUNCH와 FALL 이후 양쪽의 0번 기준12/13/14/15 네 표시 샘플, 이어 jump 표시. |
| attack | 1,583 | 양쪽 release12/13/14 이후 실제 `ja-hyun-air-light` 결과가 처음 표시되는 샘플부터 `attack_air_light`, release 비활성. 그 뒤 ACTIVE/RECOVERY도 같은 공격 표시다. |
| jump | 1,589 | 양쪽 release12/13/14/15 네 그림을 표시한 뒤 실제 JUMP 결과가 처음 표시되는 샘플부터 jump, release 비활성. 이 실행은 네 그림을 마치기 전의 중단을 입증하지 않는다. 수신된 새 결과를 다음 표시 갱신에서 즉시 반영한 범위로만 인정한다. |

합계 **4,529개**이며 원 보고서의 mode·presentation·catalog 해시·각 보고서 SHA-256·PASS/오류 없음이 일치한다. 선택 코드는 제품 `res://scripts/local_fighter_presentation.gd`, 후보 목록 해시는 `93b94a776411ee94f03bcd0ca9130ab6b92f5a1432115a45844e62642270860c`다. 156개 선택 소스의 before/after 전체 값이 같고 현재 파일 해시도 같았다. server/client/auth 모든 로그에서도 SCRIPT ERROR/ERROR/FAIL/Traceback이 없었다. 따라서 위 두 runner 결함에 해당하지 않는 이번 실제 자료를 무효화하지 않는다.

소유 관계는 실제 slot1=`lan_host`, slot2=`lan_guest`다. 자현은 slot1에서 원격, slot2에서 소유 파이터로 기록되어 있다. 모든 관찰 trace의 로컬 남은 경직·표시 duration은 0이고, 실제 수신 snapshot은 남은 경직 필드를 갖지 않았다. 결과는 localhost 소켓·상태·표시 코드 범위이며 실제 화면·Android·Wi-Fi·DB 검사는 아니다.

## fixture 범위 보완 제안

현재 `client-fixture.gd:199~202`의 `interrupted`는 나중 샘플 하나가 공격/jump 그림이면 true다. 서버 응답이 4틱보다 늦는 경우까지 무조건 실패시킬 필요는 없으나, '수신 즉시 표시'를 자동 검증하려면 trace에서 각 클라이언트의 **첫 실제 후속 결과 샘플**을 찾고, 그 샘플부터 `release_active == false`와 기대 motion을 검사해야 한다. `release_frames`가4개 미만인 경우의 중간 중단과, 4개가 끝난 뒤 수신된 새 결과의 즉시 표시를 결과 필드로 나누면 과장을 막을 수 있다. R03은 그 조건을 독립 읽기로 추가 확인했으며 기존 fixture를 수정하지 않았다.

재검산 자료는 `independent-R03-review-r01.json`에 있다. 새 runner 버전의 두 수정과 별도 독립 검토 전에는 r02 도구 전체를 pass로 바꾸지 않는다.
