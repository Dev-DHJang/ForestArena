#!/usr/bin/env python3
"""입력 양식의 확정된 값을 기본 뼈대에 한 번 적용한다. 재실행은 기존 문서를 보존한다."""
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def configure():
    state_path = ROOT / 'bootstrap-state.json'
    data = json.loads((ROOT / 'project-input.json').read_text(encoding='utf-8'))
    state = json.loads(state_path.read_text(encoding='utf-8'))
    if data.get('confirmed') is not True:
        raise ValueError('중요 입력을 사용자와 확인한 뒤 confirmed를 true로 바꿔 주세요.')
    for key in ['game_name', 'project_id', 'core_play', 'first_goal']:
        if not isinstance(data.get(key), str) or not data[key].strip() or '\n' in data[key] or '\r' in data[key]:
            raise ValueError(f'{key}: 비어 있지 않은 한 줄 문자열이 필요합니다.')
    if not re.fullmatch(r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*', data['project_id']):
        raise ValueError('project_id는 소문자 영문으로 시작하고 영문·숫자·하이픈만 사용합니다.')
    for key in ['platforms', 'excluded_features', 'optional_tools']:
        if not isinstance(data.get(key), list) or any(not isinstance(v, str) or not v.strip() or '\n' in v or '\r' in v for v in data[key]):
            raise ValueError(f'{key}: 한 줄 문자열 목록이 필요합니다.')
    for key in ['engine', 'screen_input']:
        if data.get(key) is not None and (not isinstance(data[key], str) or not data[key].strip() or '\n' in data[key] or '\r' in data[key]):
            raise ValueError(f'{key}: 한 줄 문자열 또는 null이 필요합니다.')
    if not isinstance(data.get('android'), bool):
        raise ValueError('android는 true 또는 false여야 합니다.')
    forbidden = ['Forest'+' Arena', 'Forest'+'Arena', 'forest'+'-arena', 'forest'+'_arena',
                 'Forest'+'Tales', 'com.'+'forestarena', 'com.'+'foresttales', 'starter'+'-game']
    if any(value in json.dumps(data, ensure_ascii=False) for value in forbidden):
        raise ValueError('이전 프로젝트나 임시 프로젝트 식별자를 새 게임 입력에 사용하지 마세요.')
    if re.search(r'\{\{[A-Z_]+\}\}', json.dumps(data, ensure_ascii=False)):
        raise ValueError('입력에 미치환 표시가 있습니다. 실제 값을 작성해 주세요.')
    if state['status'] == 'configured':
        if state.get('applied_input') != data:
            raise ValueError('이미 설정한 프로젝트입니다. 입력 변경을 자동 덮어쓰지 않습니다. 기존 결정과 관련 문서를 수동으로 갱신해 주세요.')
        print('configure: 이미 같은 입력으로 설정했습니다. 문서·결정을 변경하지 않았습니다.')
        return 0
    if state.get('status') != 'unconfigured':
        raise ValueError('알 수 없는 뼈대 상태입니다.')
    updates = {}
    for rel, expected_hash in state['template_hashes'].items():
        p = ROOT / rel
        if not p.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError(f'{rel}: 뼈대 밖의 경로는 적용하지 않습니다.')
        if p.is_symlink() or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != expected_hash:
            raise ValueError(f'{rel}: 기본 파일이 수정되거나 없습니다. 사용자 변경을 덮어쓰지 않습니다. 변경을 보존하며 수동으로 구성해 주세요.')
        updates[rel] = p.read_text(encoding='utf-8').replace('새 게임', data['game_name']).replace('starter-game', data['project_id'])
    skill_old = '.agents/skills/starter-game-workflow/SKILL.md'
    skill_new = f".agents/skills/{data['project_id']}-workflow/SKILL.md"
    skill_text = updates.pop(skill_old)
    description = json.dumps(f"{data['game_name']}의 문서·구현 요청과 검사 기록을 순서대로 진행한다.", ensure_ascii=False)
    skill_text = re.sub(r'^description: .*$', lambda match: 'description: '+description, skill_text, count=1, flags=re.M)
    updates[skill_new] = skill_text
    engine = data['engine'] or '미정'
    platforms = ', '.join(data['platforms']) or '미정'
    updates['README.md'] = updates['README.md'].replace(' (입력 전 임시 값)', '')
    updates['README.md'] = updates['README.md'].replace(
        '엔진 공통 사전 구성 뼈대다. 엔진·플랫폼·핵심 플레이는 아직 미정이며 게임 코드는 없다. 입력 후 제품 방향을 최종 기준으로 사용한다.',
        f'엔진: {engine}. 대상 플랫폼: {platforms}. 문서·작업 절차를 준비했으며 게임 코드는 없다. 제품 방향을 최종 기준으로 사용한다.')
    updates['docs/operations/harness/operating-index.md'] = updates['docs/operations/harness/operating-index.md'].replace(
        '기본 뼈대 준비. 게임별 입력은 미정이며 게임 코드는 없다. 최초 설정 뒤 제품 방향·개발 순서와 이 상태를 맞춘다.',
        '게임별 입력 적용. 게임 코드는 아직 없다. 구조 검사 결과는 마무리 기록에서 확인한다.')
    updates['docs/product/roadmap.md'] = updates['docs/product/roadmap.md'].replace(
        '현재: 입력 미정. 뼈대 준비와 게임별 설정 완료를 구분한다.',
        '현재: 입력 적용. 구조 검사와 마무리 기록으로 완료를 확인한다.')
    updates['docs/engineering/architecture.md'] = updates['docs/engineering/architecture.md'].replace(
        '엔진·버전: 미정.', f'엔진: {engine}. 버전: 미정.')
    updates['docs/product/vision.md'] = f'''# {data['game_name']} 제품 방향

- 프로젝트 ID: `{data['project_id']}`
- 핵심 플레이: {data['core_play']}
- 대상 플랫폼: {platforms}
- 엔진: {engine}
- 화면·입력: {data['screen_input'] or '미정'}
- 첫 개발 목표: {data['first_goal']}
- 제외 기능: {', '.join(data['excluded_features']) or '아직 미정. 구현 전에 확인한다.'}
- 선택 도구: {', '.join(data['optional_tools']) or '없음'}

미정 값은 제안 상태다. 구체적인 플레이 완료 조건은 개발 전에 사용자와 확인한다.
'''
    today = date.today().isoformat()
    updates['docs/product/decisions.md'] = f'''# 결정 기록

## DEC-001: 초기 입력

- 상태: accepted
- 날짜: {today}
- 근거: 사용자가 확인한 project-input.json의 confirmed=true 입력.
- 내용: 이름·ID·핵심 플레이·첫 목표를 위 입력대로 적용한다. null이나 빈 목록은 확정된 기능이 아니라 미정이다.
- 영향: 사전 구성만 완료하며 게임 코드·설치·계정·원격 변경은 포함하지 않는다.
- 대체 관계: 없음

## DEC-002: 남은 선택

- 상태: proposed
- 날짜: {today}
- 내용: 엔진 버전, 미정 플랫폼·입력, 구체적인 성능·출시·저장·온라인 정책은 첫 구현 전에 필요한 것부터 정한다.
- 영향: 구조 검사는 가능하며 미정 기능은 구현하지 않는다.
- 대체 관계: 없음
'''
    options = []
    if data['engine'] and data['engine'].lower() == 'godot':
        options += [('options/godot/setup.md', 'docs/engineering/godot/setup.md'),
                    ('options/godot/resource-rules.md', 'docs/engineering/godot/resource-rules.md')]
        updates['assets/resource-registry.json'] = json.dumps({'schema_version': 1, 'assets': []}, ensure_ascii=False, indent=2)+'\n'
    if data['android']:
        options += [('options/android/android.md', 'docs/engineering/android.md')]
    for source, target in options:
        updates[target] = (ROOT / source).read_text(encoding='utf-8')
        label = {'setup.md': 'Godot 준비', 'resource-rules.md': 'Godot 자산 규칙', 'android.md': 'Android 확인 계획'}[Path(target).name]
        updates['docs/INDEX.md'] += f'- [{label}]({target.removeprefix("docs/")})\n'
    for rel in updates:
        p = ROOT / rel
        if p.is_symlink() or (p.exists() and rel not in state['template_hashes']):
            raise ValueError(f'{rel}: 기존 파일이 있으므로 자동 덮어쓰기를 중단합니다.')
        for parent in p.parents:
            if parent == ROOT:
                break
            if parent.is_symlink():
                raise ValueError(f'{rel}: 심볼릭 링크 폴더에는 작성하지 않습니다.')
    summary = f'''# 사전 구성 마무리

- 상태: 입력 적용 완료, 구조 검사 확인 필요.
- 날짜: {today}
- 생성·수정: 기본 문서의 이름·ID, 제품 방향·결정·최소 스킬, 선택한 준비 문서.
- 보존: 게임 코드 없음, 설치·계정 연결·Git 원격 변경 없음.
- 실행할 검사: `python3 tools/verify_bootstrap.py --scope all --require-configured`.
- 다음 작업: 첫 개발 목표의 구체적 완료 조건을 정하고 구현·검사를 시작한다.
- 실제 검사 결과는 실행한 Codex 또는 사용자가 이 기록에 덧붙인다. 적용 도구 실행 자체를 검사 통과로 기록하지 않는다.
'''
    updates['_workspace/bootstrap/04_closeout.md'] = summary
    for rel, text in updates.items():
        p = ROOT / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding='utf-8')
    (ROOT / skill_old).unlink()
    (ROOT / skill_old).parent.rmdir()
    state = {'schema_version': 1, 'status': 'configured', 'game_name': data['game_name'],
             'project_id': data['project_id'], 'engine': 'godot' if data['engine'] and data['engine'].lower() == 'godot' else data['engine'],
             'android': data['android'], 'applied_input': data}
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('configure: 입력을 적용했습니다. 구조 검사를 실행하고 마무리 기록에 결과를 남겨 주세요.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(configure())
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'configure: FAIL: {exc}', file=sys.stderr)
        sys.exit(1)
