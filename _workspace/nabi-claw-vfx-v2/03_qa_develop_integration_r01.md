# develop 통합의 정적 콘셉트 검사 분리 독립 QA r01

판정: **PASS — 정적 concept의 현재 유효성 검사와 설치 당시 보존 감사를 나누는 변경 범위.** 원래 보호 조건의 누락이나 설치 단계 검사 약화는 발견하지 못했다. 전체 게임·미술·Android 통과를 뜻하지 않는다.

## 범위와 원인

최신 develop에서 이미 승인·등록한 정적 개성 concept 4개를 받아들이는 통합이다. 새 이미지 승인이나 새 생성이 아니다. 기존 검사는 설치 당시의 manifest 전체와 assets/scripts/scenes/forest_arena의 모든 기존 파일을 일반 `check()`에서도 계속 같은 값으로 요구하여, 이후 승인된 모션 개발까지 거부했다. 이전 실패는 `qa/develop-integration-r01/concept-check.log`의 `Existing manifest entries changed`에서 확인했다.

대상은 `tools/forest_arena/install_personality_concepts.py`의 `check(..., preserve_install_snapshot=False)` 분리와 `test_personality_registration.py` 추가 검사다. 원본/표시 코드·PNG·manifest를 이 검토에서 수정하지 않았다. 별도 경계 시험은 실제 파일 대신 메모리 안에서 읽은 값과 해시만 바꿨다.

## 읽기와 실행 결과

| 항목 | 판정 | 확인 내용 |
|---|---|---|
| 승인된 정확한 정적 4개 | pass | 고정된 보고서 해시·승인 문구·네 이미지 해시·원시 생성 파일 경로와 해시·후보 PNG 해시/규격을 계속 검사한다. 예상 manifest 항목 전체와 실제 variant 4개가 일치해야 한다. 누락·추가·중복 ID·메타데이터 대체·이미지 대체 거부가 유지된다. |
| 기존 대표 concept 보호 | pass | 설치 전 자료의 `type=concept` 항목과 현재 항목을 ID별 전체 값으로 비교하고, 기존 대표 PNG도 manifest의 고정 해시와 비교한다. 보고서에 묶인 대표 참조 해시 검사도 그대로다. 삭제·추가·항목 값 변경·PNG 변경을 거부했다. |
| 외형 데이터 | pass | 기존 `appearance['characters']` 동등 검사를 유지한다. 별도 시험에서 변경을 거부했다. 전역 자세 예외 정책은 기존 등록 검사에서 정확한 4개 정적 variant 범위인지 계속 확인한다. |
| 모션 영역 분리 | pass | 현재 정적 검사에서 이후 모션 항목 추가·수정을 허용한다. 이것은 새 모션 승인이나 모션 유효성의 통과를 뜻하지 않는다. 그 항목은 별도 모션 등록·리소스·전투 검사에서 판단한다. 기존 정적 concept 보호는 그대로 남는다. |
| 설치 당시 보존 검사 | pass | `preserve_install_snapshot=True`에서 기존 manifest 항목의 순서/전체 값 동등과 `preserved_files`의 모든 파일 해시를 요구하던 원래 두 검사를 그대로 실행한다. `install()`은 이 모드를 명시 호출한다. 새 CLI `--verify-installation-snapshot`도 같은 경로다. |
| 설치 감사 경계 시험 | pass | 메모리에서 설치 당시 manifest와 해시를 재현한 양성 기준은 통과했다. 그 상태에서 assets/scripts/scenes/forest_arena 각각의 기존 파일 하나를 변조하면 거부했다. 기존 manifest 항목 변경도 거부했다. |
| 현재 통합 자료 | pass | 검사 전 `63a45825`의 기존 manifest 126개와 현재 130개 중 추가 variant 4개를 뺀 목록이 순서까지 전체 동등했다. `animation-runtime` 122개도 전체 동등했다. 별도 `independent-manifest-and-fixed-r01.json`에 기록했다. |

설치 감사 모드를 현재 개발 트리에 직접 실행하면 종료 코드 1과 `Existing manifest entries changed during installation`로 거부한다. 이후 모션 개발이 있으므로 예상한 결과다. 일반 검사 PASS를 설치 시점의 과거 파일들이 지금도 모두 같다는 주장으로 쓰지 않는다.

## 검사 증거

모두 작업 공간 `/Users/jdh/.codex/worktrees/match-playtest-fixes/ForestArena`에서 실행했다.

```sh
python3 tools/forest_arena/test_personality_registration.py
# 14 tests: OK
python3 tools/forest_arena/install_personality_concepts.py
# PERSONALITY_CONCEPT_INSTALL: PASS (4 approved static variants; canonical sources unchanged)
python3 _workspace/nabi-claw-vfx-v2/qa/develop-integration-r01/independent-concept-boundaries-r01.py
# INDEPENDENT_CONCEPT_BOUNDARIES: PASS (16 checks)
python3 tools/forest_arena/install_personality_concepts.py --verify-installation-snapshot
# 예상 거부: 종료 코드 1, Existing manifest entries changed during installation
```

로그와 추가 시험은 `qa/develop-integration-r01/independent-*`에 있다. 추가 시험 JSON은 16개 각각의 기대 허용/거부, 결과와 거부 문구를 남긴다. `independent-input-hashes-r01.json`과 `independent-manifest-and-fixed-r01.json`으로 대상 Python 3개·manifest·외형 계약의 검사 전후 해시 동등도 확인했다. `install()`의 실제 쓰기 실행은 하지 않았으며, 기존 설치 경로의 엄격한 호출은 AST(코드 구조)로 확인하고 그 경로의 검사 동작은 메모리 시험으로 확인했다.

`./scripts/verify-docs.sh`도 PASS이며 같은 폴더 `independent-verify-docs-r01.log`에 남겼다.

## 남은 범위

이 변경에 대한 직접 수정 요청은 없다. 전체 `verify.sh`, 최종 Godot import/리소스 검사·LAN 실제 연결과 PR 통합은 통합 담당의 별도 실행 결과로 기록한다. concept 이미지를 새로 제작하거나 기존 승인 이미지를 다시 승인받았다고 기록하지 않는다.
