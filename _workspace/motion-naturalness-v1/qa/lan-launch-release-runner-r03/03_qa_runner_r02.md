# LAN 실행 도구 r03 독립 QA r02

판정: **fix — 이전 거짓 PASS 두 항목은 해결됐으나, 기본 출력 경로의 symlink 정규화 한 곳이 남았다.** 명시적 출력 폴더로 실행한 실제 product-r04 자료는 이 문제와 무관하며 아래 범위에서 유효하다. 기존 r02 코드·증거와 실제 r03/r04 자료를 수정하지 않았다.

## 해결 확인

기존 r02에서 통과하던 다른 mode 보고서와 서버 SCRIPT ERROR를 r03은 거부한다. 보고서의 고정 r10 후보 SHA 불일치·누락, auth Traceback도 거부했다. 양성 기준, 보고서 누락·fix·errors·0 checks·다른 presentation, PASS 로그 누락, client 오류, nonzero 종료, 기존 폴더·외부 경로·명시적 symlink 이탈·잘못된 presentation 경로 거부까지 확인했다.

추가 도구 `independent-boundaries-r02.py`는 socket과 subprocess를 가짜 객체로 바꿨다. 실제 포트나 프로세스를 사용하지 않았다. 총21개 중20개 기대 충족, 아래1개 실패로 종료 코드1이다. 결과는 `independent-boundaries-r02.json/.log`다. 모의 출력 하위 폴더의 runner 보고서는 실제 소켓 결과가 아니다.

## 남은 수정

**[P2] 기본 출력 분기에서도 최종 경로를 정규화해야 한다.** `run.py:12`에서 환경값을 받은 분기는 `.resolve()`하지만 기본 `BASE/'runs'/time_ns()`는 정규화하지 않는다. `runs`가 작업 공간 밖으로 향하는 symlink인 경우 `is_relative_to(_workspace)`는 문자열상 내부라고 판단하고 실제로는 외부를 mkdir하려 한다.

별도 임시 `runs` symlink를 만들고 `Path.mkdir`를 가로채 확인했다. 정규화된 mkdir 대상은 작업 공간 밖 임시 폴더였으며, 실제 외부 쓰기 전에 중단했다. 임시 symlink는 제거했다. 수정은 두 분기 전체의 결과에 `.resolve()`를 적용하여 현재 범위 검사에 넘기는 것이다. 기존 코드 파일은 직접 고치지 않았다. 이 문제는 명시적 `LAN_RELEASE_OUTPUT_DIR`로 새 폴더를 지정한 실제 product-r04 실행에는 해당하지 않는다.

검토 시점 코드 SHA-256은 `independent-source-hashes-r02.json`에 고정했다. `run.py`는 `ab3b198f09e7c8ee29e3f324c156c89fca11c30c264710cca61dfdc25eec5225`다. 새 수정 버전에는 이 결과를 재사용하지 않고 경계를 다시 검사한다.

## 실제 product-r04 자료 재검산

root가 실행한 `../lan-launch-release-product-r04`를 독립 읽기로 확인했다. 이 역할이 같은 소켓 검사를 다시 실행한 것은 아니다.

- natural **1,581**, attack **1,591**, jump **1,587**, 합계 **4,759개**. 각 mode·errors 없음·제품 presentation·각 보고서 SHA-256과 runner 기록이 일치한다.
- 후보는 고정 r10 SHA `005960d9a5ec54d29a7ca637905eaee64b33ecb6308a527debc53d46bfbed324`, 제품 코드는 `res://scripts/local_fighter_presentation.gd`다.
- 선택 소스 before/after가 전체 동등하고 server/client/auth 모든 로그에 SCRIPT ERROR/ERROR/FAIL/Traceback이 없었다. 따라서 이전 두 거짓 통과 조건에 해당하지 않는다.
- 자연 사례 양쪽 release 그림은 0번 기준12/13/14/15다. 공격·점프 사례 양쪽은12/13/14를 표시한 뒤 첫 실제 후속 결과 표본부터 각각 `attack_air_light`/jump이며 release가 비활성이다. 이번 R04에서는 두 후속 사례 모두 네 그림이 끝나기 전 중단을 관찰했다.
- 소유/원격 자현을 구분했고 모든 관찰 경직·표시 duration은0이다. `followup_display_summary`의 기록과 trace도 일치한다. 지연된 후속 결과가 자연 종료 뒤 도착하는 실행은 별도로 구분해야 하며, R03의 점프에 이 R04 관찰을 소급 적용하지 않는다.

재검산은 `independent-R04-review-r02.json`에 있다. 그림 품질·실제 화면·Android·Wi-Fi·DB 결과를 이 코드/소켓 자료로 대신하지 않는다. fixture의 첫 후속 결과부터 즉시 표시된다는 조건은 trace를 독립 읽기로 확인했으며, 현재 자동 요약 자체는 이후 올바른 표본만 존재해도 `followup_rendered=true`가 될 수 있으므로 그 차이를 유지한다.
