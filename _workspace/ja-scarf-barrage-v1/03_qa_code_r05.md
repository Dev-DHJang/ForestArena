# 빈 마지막 판정 좌표 처리 독립 재검토 r05

2026-10-24. 담당: motion_code_review. r04에서 재현한 **마지막 판정 anchor 행이 `{}`일 때 회복에서 새로운 아래 방향의 긴 천을 그리는 문제**를 재검토했다. 프로덕션·후보·목록·원화는 수정하지 않았다. 해당 수정은 **pass**이며 추가 필수 문제는 발견하지 않았다.

root가 마지막 판정 행을 읽은 직후 `last_active.is_empty()`이면 반환하도록 추가했다. 따라서 회복에서는 빈 과거 좌표를 “방향 지정 없음”인 함수 기본값으로 전달하지 않는다. 유효한 마지막 hand/tip 좌표가 있는 경로는 기존과 같고, 실제 후보26번 행이 정상인 촬영 경로에도 변화가 없다. 다른 공격·준비·전투 snapshot·LAN 형식은 바꾸지 않는다.

r04의 독립 QA 재현 파일 `qa/code-r04/missing-heading.gd`를 수정하지 않고 다시 실행했다. 제품 `_draw()`를 실행한 결과:

```text
EMPTY_LAST_ACTIVE_DRAW: paths=0 snapshot_unchanged=true
```

증거는 `qa/code-r05/missing-heading.log`다. 이전의 `paths=1`과 새 아래 방향 출력이 사라졌으며, 전투 snapshot도 그대로다.

영구 검사로 추가한 ObservedEffects는 실제 제품 `_draw()`를 사용하고 `_cloth()` 호출만 관찰한다. 빈 마지막 행에서는0개, 유효 hand/tip으로 바꾸면1개와 이전 위 방향 유지, 같은 snapshot을 확인하므로 모든 효과를 무조건 끄는 수정으로 통과할 수 없다. 직접 재실행한 `qa/code-r05/vfx.log`는 **TWO_FIGHTER_VFX PASS**다. `git diff --check`도 통과했다.

검토 해시:

| 파일 | SHA256 |
| --- | --- |
| `scripts/fighter_attack_effects.gd` | `c2ff9086b8c150008d805e4ab1935e2cc495a63d00b9ee19128a0f8ea6cf5b6f` |
| `tests/two_fighter_vfx.gd` | `40c9da032977fe321e4406b1db48f6c23213f258d2e967ce58dc5ff3b479b471` |

Presentation은 r04의 `63d1294f...` 해시, FighterController는 r02의 `63dc815d...` 해시 그대로다. 새 정상/반전 r05 촬영·시각 QA는 진행 중인 별도 확인 범위이며 이 기록이 전체 모션 품질, 사용자 승인, 실제 Android 검사 통과를 대신하지 않는다.
