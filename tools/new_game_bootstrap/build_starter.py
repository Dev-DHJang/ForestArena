#!/usr/bin/env python3
"""재사용할 게임 사전 구성 뼈대를 ZIP 하나로 만든다."""
import argparse
import hashlib
import json
from pathlib import Path
import stat
import zipfile

REPO = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent


def files():
    result = {}
    def add(path, text):
        result[path] = text.strip()+'\n'
    add('START_HERE.md', '''# 기본 뼈대 시작하기

이 압축 파일은 게임 개발 전 문서·작업 절차·스킬·구조 검사를 준비한다. Python 3.9 이상만 필요하며 엔진·플러그인 설치가 필요하지 않다. 게임 코드는 포함하지 않는다.

## 사용 순서

1. 새 빈 폴더에 압축을 푼다. 숨김 폴더 `.agents`도 함께 풀어야 한다.
2. 이 폴더를 Codex에서 열고 아래 요청문을 전달한다.
3. `project-input.json`에 확인한 입력을 작성한다. 모르는 엔진·화면·플랫폼은 null 또는 빈 목록을 유지한다.
4. 중요한 값과 사용자의 답변을 확인한 뒤 `confirmed`를 true로 바꾸고 `python3 tools/configure_project.py`를 실행한다.
5. `python3 tools/verify_bootstrap.py --scope all --require-configured`를 실행하고 실제 결과를 `_workspace/bootstrap/04_closeout.md`에 남긴다.

macOS·Linux에서는 `./scripts/verify.sh`도 사용할 수 있다. ZIP을 푸는 도구가 실행 권한을 보존하지 않았다면 `sh scripts/verify.sh`를 사용한다. Windows에서는 Python 명령을 사용한다.

입력 전의 `python3 tools/verify_bootstrap.py --scope all` 통과는 뼈대가 준비됐다는 뜻이다. 게임별 입력 적용 완료와 게임 실행 완료는 별도다.

## Codex 시작 요청문

```text
이 폴더의 START_HERE.md와 docs/operations/new-game-bootstrap.md를 따라 게임 개발 준비를 완료해 주세요.
기존 파일과 지시를 먼저 확인하고 중요한 누락은 한 번에 묶어서 질문해 주세요.
이름·ID·핵심 플레이·첫 목표를 확인한 뒤 project-input.json에 기록하고 configure_project.py를 실행해 주세요.
나머지 미정은 제안으로 유지하고 --require-configured 구조 검사 결과를 마무리 기록에 남겨 주세요.
게임 코드, 도구 설치, 계정 연결, Git 원격 변경은 이번 준비에 포함하지 않습니다.
```

## 입력과 재실행

- 필수: game_name(이름), project_id(소문자 영문·숫자·하이픈), core_play(핵심 플레이), first_goal(첫 목표), confirmed(사용자 확인).
- 선택: platforms(목록), engine(이름 또는 null), screen_input(한 줄 또는 null), excluded_features(목록), optional_tools(목록), android(true/false).
- Godot 문서를 활성화하려면 engine을 `godot`으로 쓴다. Android 확인 계획을 활성화하려면 android를 true로 쓴다. 서로 독립적으로 선택할 수 있다.
- 같은 입력으로 다시 실행하면 파일을 변경하지 않는다. 설정 뒤 입력을 바꾸면 자동 적용을 중단한다. 바뀐 요구는 결정 기록과 관련 문서를 보존하며 수동으로 반영하고 bootstrap-state.json의 applied_input도 실제 승인 입력에 맞춘다.
- 설정 전에 문서가 이미 수정됐다면 도구는 덮어쓰지 않는다. 기존 변경을 보존하며 지침서에 따라 수동으로 구성한다. 수동 구성 시 bootstrap-state.json의 상태·이름·ID·선택 항목·applied_input을 실제 입력과 일치시키고 template_hashes는 제거한다.

## 기존 프로젝트에 사용할 때

압축을 기존 프로젝트 위에 바로 풀지 않는다. 별도 빈 폴더에 풀고 지침서의 기존 프로젝트 절차에 따라 필요한 문서·스킬·검사만 비교해 보완한다. 기존 문서·코드·결정·검사 명령을 덮어쓰지 않는다. configure_project.py는 이 뼈대의 최초 설정 도구이며 기존 저장소에 강제로 적용하는 도구가 아니다.

## 검사 범위

문서·상대 링크·제목 링크·색인 연결, 역할 책임·스킬 형식과 이름, 필수 파일·미치환 값·다른 프로젝트 ID·선택 구성 문서를 확인한다. 코드 블록·인라인 코드의 예시 링크는 제외한다. 지원하지 않는 참조형 링크는 실패로 보고한다.

이미지·모션·소리 제작, 승인, 등록, 실제 게임 연결은 별도 상태다. 자동 검사·에뮬레이터·물리 기기도 별도로 기록한다. 게임 실행 검사는 구현 이후 추가한다.
''')
    add('AGENTS.md', '''# 새 게임 작업 안내

- 목적과 현재 범위는 README.md, 문서 위치는 docs/INDEX.md에서 확인한다.
- 쉬운 한국어를 먼저 쓰고 전문 용어는 첫 등장에 뜻을 설명한다.
- 역할과 담당 선택은 docs/operations/harness/team-spec.md 한 곳에서 관리한다.
- 기본은 단일 에이전트이며 역할 구분만으로 다른 에이전트를 실행하지 않는다.
- 기존 결정·사용자 변경을 보존한다. 미정은 proposed(제안)로 기록한다.
- 작업마다 _workspace/<topic>/00_request.md와 04_closeout.md를 남긴다.
- 문서: ./scripts/verify-docs.sh, 역할·스킬: ./scripts/verify-harness.sh, 전체 구조: ./scripts/verify.sh.
- 셸이 없으면 python3 tools/verify_bootstrap.py --scope all을 실행한다.
- 입력 적용 완료는 --require-configured로 확인한다. 게임·기기 실행 통과와 구분한다.
- 설치·계정 연결·원격 작업은 사용자 요청이 있을 때 해당 범위만 진행한다.
''')
    add('README.md', '''# 새 게임

프로젝트 ID: `starter-game` (입력 전 임시 값).

엔진 공통 사전 구성 뼈대다. 엔진·플랫폼·핵심 플레이는 아직 미정이며 게임 코드는 없다. 입력 후 제품 방향을 최종 기준으로 사용한다.

## 시작

[사용 순서](START_HERE.md) → [문서 색인](docs/INDEX.md) → [제품 방향](docs/product/vision.md) → [운영 상태](docs/operations/harness/operating-index.md).

## 검사

Python 3.9 이상으로 `python3 tools/verify_bootstrap.py --scope all`을 실행한다.
macOS·Linux: `./scripts/verify-docs.sh`, `./scripts/verify-harness.sh`, `./scripts/verify.sh`.
입력 적용 완료: `python3 tools/verify_bootstrap.py --scope all --require-configured`.

## 충돌 처리

사용자의 현재 지시와 명시적인 승인 근거를 먼저 확인한다. README·분야 문서·승인 결정이 충돌하면 출처를 기록하고 질문한다. 작업 기록은 승인 결정을 대신하지 않는다.
''')
    add('docs/INDEX.md', '''# 문서 색인

## 처음 읽기

1. [README](../README.md)
2. [제품 방향](product/vision.md)
3. [개발 순서](product/roadmap.md)
4. [현재 운영 상태](operations/harness/operating-index.md)

## 목적별 기준

- 범위·핵심 플레이: [제품 방향](product/vision.md)
- 중요한 선택: [결정 기록](product/decisions.md)
- 코드·데이터 책임: [기술 기준](engineering/architecture.md)
- 자산·출처·승인: [콘텐츠 기준](content/art-and-audio.md)
- 작업 기록과 검사: [작업 절차](operations/ai-development.md)
- 역할과 스킬: [팀 명세](operations/harness/team-spec.md)
- 사전 구성 설명: [독립 지침서](operations/new-game-bootstrap.md)

## 폴더

product는 제품·결정, engineering은 기술·플랫폼, content는 자산 기준, operations는 작업 절차를 담는다. `.agents/skills`는 반복 작업 지침이며 `_workspace`는 요청·마무리 기록이다. 같은 규칙은 한 문서에 쓰고 다른 곳에서는 연결한다.

## 선택 구성

선택한 항목의 준비 문서는 최초 설정 도구가 아래에 연결한다. 선택하지 않은 문서 예시는 `options/`에 보관한다.
''')
    add('docs/product/vision.md', '''# 새 게임 제품 방향

- 프로젝트 ID: `starter-game`
- 핵심 플레이·첫 개발 목표: 미정. 입력 양식에서 확인한다.
- 대상 사용자·플랫폼·엔진·화면·입력: 미정.
- 포함: 개발 전 문서·최소 스킬·작업 절차·구조 검사.
- 제외: 이번 사전 구성에서 게임 코드·서버·DB·최종 자산·설치·계정 연결·원격 변경.
- 선택 도구: 없음.

미정 값은 제안 상태다. 게임 이름과 ID도 최초 설정 전 임시 값이다.
''')
    add('docs/product/roadmap.md', '''# 개발 순서

## 사전 구성

시작: 핵심 입력 확인. 산출물: 제품·기술·콘텐츠·작업 문서, 최소 스킬, 구조 검사.
완료: --require-configured 구조 검사 통과와 요청·마무리 기록.
현재: 입력 미정. 뼈대 준비와 게임별 설정 완료를 구분한다.

## 첫 플레이 흐름

제품 방향의 첫 목표에서 입력 → 상태 변화 → 결과 확인을 구체적으로 정한다.
시작: 완료 조건과 제외 범위 확인. 산출물: 최소 플레이 흐름과 자동 테스트 또는 이름 있는 수동 재검사.
완료: 정한 흐름을 실제로 실행해 확인하고 플랫폼별 미확인 사항을 보고한다.
현재: 미구현.

## 이후 개발

첫 흐름을 검증한 뒤 다음 기능을 선택한다. 저장·온라인·경제·출시 단계는 자동 기본값이 아니며 필요할 때 별도 결정한다.
''')
    add('docs/product/decisions.md', '''# 결정 기록

## DEC-001: 초기 입력

- 상태: proposed (제안).
- 근거: 아직 게임별 입력을 확인하지 않았다.
- 내용: 이름·ID·핵심 플레이·첫 목표를 사용자와 확인한다.
- 영향: 뼈대 구조 검사는 가능하며 게임별 구성 완료는 아니다.
- 대체 관계: 없음.

결정에는 날짜·근거·내용·영향·대체 관계를 적는다. accepted는 사용자 승인, superseded는 다른 결정으로 대체됐다는 뜻이다. 미정은 승인으로 올리지 않는다.
''')
    add('docs/engineering/architecture.md', '''# 기술 기준

- 엔진·버전: 미정. 설치·실행·패키징은 게임 구현 이후 준비한다.
- 게임 구현은 입력·상태·규칙·결과를 담당한다. 화면·이미지·소리는 그 결과를 보여 준다.
- 표현 프레임을 게임 판정의 기준으로 사용하지 않는다.
- 여러 코드가 함께 쓰는 데이터 형식·ID·저장 버전은 변경 전 사용하는 곳과 이전 데이터 처리 방법을 기록한다.
- 공용 데이터 변경은 _workspace/<topic>/01_contract.md에 이전·새 형식과 검사를 적는다.
- 구조 검사는 Python 표준 라이브러리만 사용한다. 실제 실행 검사는 구현·선택 환경이 준비된 뒤 추가한다.
- 저장·온라인·서버·DB는 필요에 따라 결정하며 사전 구성에 강제로 포함하지 않는다.
''')
    add('docs/content/art-and-audio.md', '''# 콘텐츠 기준

시각·소리 방향은 미정이다. 먼저 작은 화면에서도 상태와 조작을 알아볼 수 있도록 계획한다. 외부 자산이 없어도 임시 도형으로 첫 플레이를 만들 수 있어야 한다.

## 자산 상태

제작 → 검토·승인 → 등록 → 실제 게임 연결 → 연결 검사를 각각 기록한다. 등록만으로 게임에서 사용한다고 표시하지 않는다. 승인 담당과 방법은 제작 전에 정하며 요구한 승인 없이 최종 자산을 교체하지 않는다.

## 출처와 이용 조건

자산 ID, 종류, 원본·파생 경로, 제작자·생성 방법, 원본 URL 또는 제공 경로, 날짜·버전, 이용 조건과 근거, 수정 내용, 승인자·날짜·대상 버전, 등록 위치, 실제 사용 위치, 연결 검사 결과를 기록한다. 권리 미확인은 허가가 아니다.

원본·가공 파일·게임에서 사용하는 파일을 구분한다. 그림과 소리는 게임 결과를 표현하며 규칙을 계산하지 않는다.
''')
    add('docs/operations/ai-development.md', '''# 작업 절차

1. README·색인·현재 상태·승인 결정을 확인한다.
2. _workspace/<topic>/00_request.md에 날짜·목표·기존 상태·범위·제외·완료 조건·검사를 적는다.
3. 필요한 설계만 추가하고 요청 범위의 문서나 코드를 작성한다.
4. 문서·역할·전체 구조를 검사하고 원 요청과 결과를 비교한다.
5. _workspace/<topic>/04_closeout.md에 상태·변경 파일·실제 검사·실패·미실행 이유·재개 조건·미정·다음 작업을 적는다.

기본 기록은 요청·마무리 두 개다. 공용 데이터 변경은 01_contract.md, 실질적인 역할 전달은 02_<role-id>.md, 별도 품질 확인은 03_qa_rNN.md를 필요한 경우만 추가한다.

같은 작업 재실행은 기존 기록에 날짜별로 덧붙이고 결정을 중복 생성하지 않는다. 새 기능은 자동 테스트 또는 이름 있는 수동 재검사를 포함한다. 실행하지 않은 검사를 통과로 기록하지 않는다. 자동·에뮬레이터·물리 기기 결과를 구분한다.

실패는 원인을 수정한 뒤 관련 검사를 다시 실행한다. 요구 충돌은 제안 결정과 질문으로 해결한다. 같은 원인이 반복되면 접근을 재검토한다. 미실행은 필요한 환경과 재개 조건을 적는다.

쉬운 한국어를 먼저 쓰고 전문 용어는 처음 뜻을 설명한다. 두 문서 이상에서 반복되는 전문 용어는 필요할 때 docs/GLOSSARY.md에 추가한다. 새 문서나 파일을 추가하면 색인도 갱신한다.
''')
    add('docs/operations/harness/team-spec.md', '''# 팀 명세

활성 역할과 스킬 목록의 단일 원본이다. 기본은 단일 에이전트가 아래 책임을 순서대로 맡는다. 역할 분리만으로 여러 에이전트를 실행하지 않는다.

| role-id | 담당 책임 | skill-id |
| --- | --- | --- |
| planning-content | 제품(product), 콘텐츠(content) | starter-game-workflow |
| development | 게임 구현(gameplay), UI(ui), 플랫폼(platform), 공용 데이터(data) | starter-game-workflow |
| review | 품질 확인(qa) | starter-game-workflow |

스킬 경로는 `.agents/skills/<skill-id>/SKILL.md`다. 범위·결정은 planning-content, 작성은 development, 요청 대조·검사는 review가 맡는다. 같은 에이전트의 검사를 독립 검토라고 보고하지 않는다.

Godot 자산·애니메이션·오디오·네트워크 등의 반복 전문 작업이 실제 필요해질 때 스킬을 추가하고 이 표도 갱신한다. 단일 작업 때문에 모든 역할을 분리하지 않는다.

사용자 요청이나 프로젝트 지시가 여러 에이전트 실행을 허용하고 독립 작업의 실익이 분명할 때 담당 파일·환경·통합 담당·부분 실패 처리를 정한다. 같은 파일·기기 작업은 순서대로 하거나 환경을 분리한다.

전달·실패·완료 기록은 [작업 절차](../ai-development.md)를 따른다. 자동 원격 병합은 기본 정책에 포함하지 않는다.
''')
    add('docs/operations/harness/operating-index.md', '''# 현재 운영 상태

## 현재 단계

기본 뼈대 준비. 게임별 입력은 미정이며 게임 코드는 없다. 최초 설정 뒤 제품 방향·개발 순서와 이 상태를 맞춘다. 역할 목록은 [팀 명세](team-spec.md) 한 곳에서 관리한다.

## 검사 명령

- 문서: `./scripts/verify-docs.sh`
- 역할·스킬: `./scripts/verify-harness.sh`
- 전체 구조: `./scripts/verify.sh`
- 셸 없이 실행: `python3 tools/verify_bootstrap.py --scope all`
- 입력 적용 완료: `python3 tools/verify_bootstrap.py --scope all --require-configured`

Python 3.9 이상 필요. 실행하지 못하면 환경과 재개 조건을 기록한다. 게임 실행 검사는 구현 이후 추가한다.

## 미확인

엔진 버전·플랫폼·입력·성능·출시 설정은 필요한 것부터 결정한다. 외부 도구는 없음. 도구를 선택하면 필요성·준비 상태·설치나 연결에 필요한 별도 요청·대체 방법을 기록한다.
자동·에뮬레이터·물리 기기 검사는 구현 뒤 각각 환경·날짜·버전·증거와 함께 기록한다. 구조 검사 통과가 게임 실행이나 기기 통과를 뜻하지 않는다.
''')
    add('.agents/skills/starter-game-workflow/SKILL.md', '''---
name: starter-game-workflow
description: "새 게임의 문서·구현 요청과 검사 기록을 순서대로 진행한다."
---

# 새 게임 작업 흐름

## 사용 시점

프로젝트의 문서·구현·검사 요청을 수행할 때 사용한다. 담당 책임은 docs/operations/harness/team-spec.md에서 고른다.

## 필수 입력

사용자 목표·범위·제외·완료 조건, 색인에서 찾은 기준, 현재 운영 상태. 중요한 누락은 기존 파일 조사 뒤 묶어서 질문한다.

## 작업 흐름

1. 기존 파일·결정·사용자 변경을 확인한다.
2. _workspace/<topic>/00_request.md에 범위와 검사를 적는다.
3. 공용 데이터 변경이면 01_contract.md를 먼저 작성한다.
4. 허용된 범위만 작성한다. 사전 구성에서는 게임 코드를 만들지 않는다.
5. 관련 검사와 전체 구조 검사를 실행한다.
6. 원 요청과 결과를 대조하고 04_closeout.md를 작성한다.

## 산출물과 검증

요청한 파일과 요청·마무리 기록을 남긴다. 문서는 verify-docs.sh, 역할·스킬은 verify-harness.sh, 전체 구조는 verify.sh로 확인한다. 실패·미실행 이유와 재개 조건을 기록하며 실행하지 않은 검사를 통과로 표시하지 않는다.
''')
    add('_workspace/bootstrap/00_request.md', '''# 사전 구성 요청

- 상태: 게임별 사용자 입력 확인 전.
- 목표: 문서·최소 스킬·작업 절차·구조 검사 구성.
- 기존 상태: 독립 압축 파일의 기본 뼈대.
- 포함: 입력 적용, 선택 준비 문서, 구조 검사.
- 제외: 게임 코드·설치·계정 연결·Git 원격 변경.
- 완료 조건: 입력 확인 후 --require-configured 검사와 마무리 기록.
- 검사 계획: 문서·역할·전체 구조 검사.
- 실제 요청 날짜·답변 근거·게임별 포함·제외 범위는 설정을 진행한 사용자가 덧붙인다.
''')
    add('_workspace/bootstrap/04_closeout.md', '''# 사전 구성 마무리

- 상태: 기본 뼈대 준비. 게임별 설정·검사는 아직 실행하지 않았다.
- 생성 파일: 공통 문서·최소 스킬·설정 도구·구조 검사·선택 구성 예시.
- 실행할 검사: python3 tools/verify_bootstrap.py --scope all --require-configured.
- 미정: 게임 입력.
- 다음 작업: START_HERE.md의 순서대로 입력을 확인하고 적용한다.
- 실제 검사 명령·결과·실패·미실행 이유·재개 조건을 날짜와 함께 기록한다.
''')
    add('options/godot/setup.md', '''# Godot 준비

선택 엔진은 Godot이며 버전은 미정이다. 설치 여부와 향후 편집기·화면 없는 검사·내보내기에 필요한 환경을 확인해 기록한다. 초기 구성에는 project.godot·장면·게임 코드·설치를 포함하지 않는다.

게임 구현 이후 사용할 실행 명령은 실제 버전과 프로젝트 경로를 확인한 뒤 README에 추가한다. 아직 실행할 수 없는 명령을 통과했다고 기록하지 않는다.
''')
    add('options/godot/resource-rules.md', '''# Godot 자산 규칙

코드는 논리 자산 ID를 통해 자산을 찾도록 설계한다. 예: ui.confirm. 실제 파일 경로는 assets/resource-registry.json에 기록한다.

등록 목록은 schema_version과 assets 배열을 사용한다. 각 자산은 id, kind, path, variants, production_status, approval_status, source_record 필드를 갖도록 계획한다. 자산이 없으면 배열은 비어 있어도 된다. 없는 파일을 가짜 경로로 등록하지 않는다.

등록 담당·누락 처리·품질별 대체 규칙은 구현 전에 정한다. 실제 사용이 시작되면 ID 중복·파일 누락·잘못된 품질 참조·미등록 ID 사용 검사를 추가한다. 시작 때 자동으로 준비하는 객체(Autoload)는 구현 이후 만든다.

승인·등록·실제 연결·연결 검사는 별도 상태다. 등록됐다고 게임에 연결된 것은 아니다.
''')
    add('options/android/android.md', '''# Android 확인 계획

초기 구성에는 SDK 설치·기기 페어링·APK 생성·스토어 연결을 포함하지 않는다.

| 영역 | 계획할 확인 |
| --- | --- |
| 터치·화면 | 방향, 화면 비율 표본, 안전 영역, 터치 크기·동시 입력·입력 취소 |
| 중단·복귀 | 홈·잠금 등 중단 후 입력 초기화·소리·상태 복원 |
| 성능 | 목표 FPS·프레임 시간·메모리·발열·배터리의 제안, 측정 기기·상황·방법 |
| 패키징 | 패키지 ID의 결정 상태, 개발·출시 구분, 서명 정보 별도 보관 |
| 결과 | 자동 검사·에뮬레이터·물리 기기를 각각 날짜·환경·버전·증거·미확인과 함께 기록 |

기기가 없으면 물리 기기는 미실행이다. 에뮬레이터나 데스크톱 키보드 검사는 물리 기기 터치 확인을 대신하지 않는다. 성능 한도는 실제 기기 측정 후 확정한다.
''')
    add('.gitignore', '''.DS_Store
__pycache__/
*.py[cod]
.godot/
.env
.env.*
!.env.example
build/
''')
    guide = (REPO/'docs/operations/new-game-bootstrap.md').read_text(encoding='utf-8').split('## 8. Forest Arena 경험과 참고 자료')[0]
    guide = guide.replace('마지막의 Forest Arena 자료는 작성 근거이며 구성에 필요한 입력이 아니다.', '이 복사본은 외부 참고 링크 없이 필요한 절차를 모두 담는다.')
    add('docs/operations/new-game-bootstrap.md', guide)
    for tool in ['configure_project.py', 'verify_bootstrap.py']:
        add('tools/'+tool, (SOURCE/tool).read_text(encoding='utf-8'))
    for filename, scope in [('verify-docs.sh','docs'), ('verify-harness.sh','harness'), ('verify.sh','all')]:
        add('scripts/'+filename, f'''#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$ROOT/tools/verify_bootstrap.py" --scope {scope} "$@"
''')
    input_data = dict(game_name=None, project_id=None, core_play=None, platforms=[], engine=None,
                      screen_input=None, first_goal=None, excluded_features=[], optional_tools=[], android=False, confirmed=False)
    add('project-input.json', json.dumps(input_data, ensure_ascii=False, indent=2))
    owned = [p for p in result if (p.endswith('.md') and p != 'docs/operations/new-game-bootstrap.md' and not p.startswith('options/'))]
    state = dict(schema_version=1, status='unconfigured', game_name='새 게임', project_id='starter-game', engine=None, android=False,
                 template_hashes={p: hashlib.sha256(result[p].encode()).hexdigest() for p in owned})
    add('bootstrap-state.json', json.dumps(state, ensure_ascii=False, indent=2))
    return result


def build(output):
    payload = files()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, text in sorted(payload.items()):
            entry = zipfile.ZipInfo('game-starter/'+path, date_time=(2026, 10, 9, 0, 0, 0))
            entry.create_system = 3
            mode = 0o755 if path.endswith('.sh') or path.startswith('tools/') else 0o644
            entry.external_attr = (stat.S_IFREG | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, text.encode('utf-8'))
    print(f'{output}: {len(payload)} files, {output.stat().st_size} bytes')
    print('sha256: '+hashlib.sha256(output.read_bytes()).hexdigest())
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPO/'artifacts/new-game-starter-v1.zip')
    args = parser.parse_args()
    build(args.output.resolve())
