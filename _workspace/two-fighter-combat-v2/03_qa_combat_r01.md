# 전투 동작 독립 확인 1차

## 범위와 판정

판정: **pass**. 이번 확인은 새 두 캐릭터의 전투 계산·입력·상태·기술 데이터와 제품 화면 연결에 한정한다. 코어 생산 파일은 변경하지 않았다. 새 모션의 행위 표현·사용자 승인과 실제 Android 검사는 별도이며 이 기록으로 통과시키지 않는다.

`00_request.md`, `01_contract.md`를 기준으로 AttackData v4, CombatRules v5, 두 MoveSet, FighterController, HitResolver, MatchController, PushboxResolver 및 제품·AI·LAN의 읽는 부분을 비교했다.

## 실행 증거

- `godot --headless --path . --script res://tests/two_fighter_combat_v2.gd`: PASS. 방향 통합과 연계4/3회, 강 단타, 공중 약/강 별도 횟수, 새 피격으로120tick 연장·재시작 금지, 착지 다운18/기상 보호12, 실제10펄스·총14피해·가드·피격 중단, 나비 첫 적/빈 이동/벽/점유/가드/중단, 동시 피격과 동일 상태 재현을 확인했다. 최신 검사 격리 보완 뒤 다시 PASS했다.
- 독립 작성한 `tests/two_fighter_combat_boundaries.gd`: PASS. 일반 피격 경직30tick 중 추가 잠금이2tick 뒤 끝나도 일반 경직28tick이 남았다. 실제 옆벽에 닿아도 바닥 접촉이 아니면 공중 약/강 사용 기록과 잠금110tick이 유지됐다. 자현 특수에 늦게 들어온 상대는5회·9피해만 받고 마지막 시점에는 바깥으로 밀렸다. 나비의 상대가 이동 시작 후720→1100으로 이동해도 종점784를 유지하고 빗나갔다.
- `tests/two_fighter_product.gd`: 착지 표시 보완 뒤 PASS. 실제 앱2/4/8명 ×1280/1600×720 ×글자1.0/1.3배의 HUD와 새4버튼 검사 포함. 기존 `match_playtest_ui.gd` 기본 경로는 이전6버튼을 검사하므로 새4버튼 검증으로 계산하지 않았다. 이 실행은 화면 좌표/판정 자동 검사이며 새 스크린샷의 시각 평가를 대신하지 않는다.
- `python3 tools/forest_arena/verify_godot_resources.py --project-root .`: PASS,519개 논리 자산·25개 품질 차이.
- 수정한 UI/제품/경계 검사 파일의 `git diff --check`: PASS.

원시 실행 기록: `/tmp/fa-independent-core.log`, `/tmp/fa-independent-boundaries.log`, `/tmp/fa-product-final.log`. 경계 검사는 저장소 파일로 남겨 임시 파일 없이 다시 실행할 수 있다.

## 발견과 처리

1. **fix → pass: 착지 다운 표시.** 코어 담당의 독립 교차검토에서 공중 잠금이 풀린 착지 다운18tick 동안 터치가 공격을 준비 상태로 표시하는 문제를 찾았다. UI가 `landing_down_ticks`도 읽어 점프·약·강·특수 그림을 비활성으로 표시하고 세 공격의 문구를 `행동 불가`로 보여 주도록 보완했다. 다음 snapshot의 다운0에서 다시 준비로 복원하고 원본 snapshot을 바꾸지 않는 자동 검사를 추가했다. 입력 허용/차단은 기존 코어가 계속 결정한다.
2. **fix → pass: 검사 원본 리소스 공유.** 신규 코어 검사에서 카탈로그의 깊은 복제만으로 외부 CharacterData가 분리되지 않아 원본 캐시의 MoveSet 연결이 바뀔 수 있었다. 코어 담당에게 전달했고 각 CharacterData를 먼저 복제한 다음 새 MoveSet을 연결하도록 수정했다. 검사 마지막에 원본 Ja MoveSet 포인터 불변도 검사하며 최신 suite가 PASS했다. 제품 LocalPlayCatalog는 이미 같은 분리를 하고 있다.

## 읽기 검토 결과와 한계

방향 선택은 새 규칙 경로에서 중립 입력으로 정리하되 좌우 바라보기와 공중 횟수는 별도로 유지한다. 약 연계는 기존 ComboLink의 입력 행동을 사용하므로 상하 방향으로 새 기술이 선택되지 않는다. 120tick 만료는 추가 잠금과 아직 시작하지 않은 착지 효과만 해제하며 일반 hitstun과 사용한 공중 기회는 보존한다. 착지는 `is_on_floor()`를 요구하므로 옆벽 접촉으로 기회가 되살아나지 않는다.

펄스별 공격 복사본과 시점별 적중 키를 쓰며 타격 후보를 먼저 모아 정렬하므로 동시 타격과 한 펄스의 중복 영역을 일관되게 처리한다. 이동 종점은 처음 고른 적 위치에서 고정하고 종점 점유·전체 지형 이동을 검사하며, 체력 피해·가드·피격 중단은 일반 공격 경로를 거친다. 새 상태 snapshot의 기본값·reset·stock/respawn 경로를 확인했고 LAN은 해당 값을 표시용으로 복원한다.

AI의18tick 판단 간격·seed 초기화·90tick 목표 유지·5전술·퇴각 시 발판 여유·적이 없어도 먼저 복귀하는 분기를 읽어 확인했다. 새 제품 경로는 삭제 행동과 강 해제를 만들지 않고 공중 특수를 요청하지 않으며, 공중 기회/잠금과 실제 강 사거리를 읽는다. 앞선 `tests/two_fighter_ai.gd`의4대진+동일 seed 전체 경기 재생 PASS(5,162~7,534tick)는 그대로 참고하고 이번 독립 검토에서 긴 자동 대전을 중복 실행하지 않았다.

미해결 코어 동작 결함은 발견하지 못했다. 제품 검사 종료 때 ObjectDB10개/Resource5개 정리 경고가 남아 있으며 기능 PASS와 구분한다. 새 모션 승인·기기 조작/표현·실기기 LAN 결과는 이번 pass 범위에 포함하지 않는다.
