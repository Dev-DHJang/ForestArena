#!/usr/bin/env python3
"""새 게임 뼈대의 문서·역할·설정 구조 검사. Python 표준 라이브러리만 사용한다."""
import argparse
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
CORE = [
    'START_HERE.md', 'AGENTS.md', 'README.md', 'project-input.json',
    'bootstrap-state.json', 'docs/INDEX.md', 'docs/product/vision.md',
    'docs/product/roadmap.md', 'docs/product/decisions.md',
    'docs/engineering/architecture.md', 'docs/content/art-and-audio.md',
    'docs/operations/ai-development.md', 'docs/operations/new-game-bootstrap.md',
    'docs/operations/harness/team-spec.md', 'docs/operations/harness/operating-index.md',
    '_workspace/bootstrap/00_request.md', '_workspace/bootstrap/04_closeout.md',
]
TOOLS = ['tools/configure_project.py', 'tools/verify_bootstrap.py',
         'scripts/verify-docs.sh', 'scripts/verify-harness.sh', 'scripts/verify.sh']
RESPONSIBILITIES = {'product', 'gameplay', 'ui', 'content', 'platform', 'data', 'qa'}
ID_PATTERN = r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*'
GUIDE = 'docs/operations/new-game-bootstrap.md'
OPTIONAL = {
    'godot': ['docs/engineering/godot/setup.md', 'docs/engineering/godot/resource-rules.md',
              'assets/resource-registry.json'],
    'android': ['docs/engineering/android.md'],
}
FORBIDDEN = ['Forest' + ' Arena', 'Forest' + 'Arena', 'forest' + '-arena',
             'forest' + '_arena', 'Forest' + 'Tales', 'com.' + 'forestarena',
             'com.' + 'foresttales']


def prose(text):
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r'^\s*(`{3,}|~{3,})', line)
        if marker:
            if fence is None:
                fence = marker.group(1)[0]
            elif marker.group(1)[0] == fence:
                fence = None
            lines.append('')
        elif fence is None:
            lines.append(re.sub(r'(`+).*?\1', '', line))
        else:
            lines.append('')
    return '\n'.join(lines)


def anchors(text):
    counts, result = {}, set()
    for line in prose(text).splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if not match:
            continue
        slug = re.sub(r'[^\w\s-]', '', match.group(1).lower()).replace(' ', '-')
        number = counts.get(slug, 0)
        counts[slug] = number + 1
        result.add(slug if number == 0 else f'{slug}-{number}')
    return result


def run(scope, require_configured=False):
    errors = []
    def fail(path, reason):
        errors.append(f'{path}: {reason}')
    def require(path):
        p = ROOT / path
        if not p.is_file() or not p.read_bytes().strip():
            fail(path, '필수 파일이 없거나 비어 있습니다. 복원해 주세요.')
            return False
        return True
    try:
        state = json.loads((ROOT / 'bootstrap-state.json').read_text(encoding='utf-8'))
        if state.get('schema_version') != 1 or not re.fullmatch(ID_PATTERN, state.get('project_id', '')):
            raise ValueError('설정 버전 또는 프로젝트 ID 오류')
        if state.get('status') not in {'unconfigured', 'configured'}:
            raise ValueError('잘못된 설정 상태')
    except (OSError, ValueError, TypeError) as exc:
        fail('bootstrap-state.json', f'설정을 읽을 수 없습니다: {exc}')
        state = {'status': 'unconfigured', 'project_id': 'starter-game', 'engine': None, 'android': False}
    if require_configured and state['status'] != 'configured':
        fail('project-input.json', '게임 입력을 확인하고 configure_project.py를 실행해 주세요.')
    required = list(CORE)
    for option, paths in OPTIONAL.items():
        enabled = state.get('engine') == 'godot' if option == 'godot' else state.get('android')
        if enabled:
            required += paths
    if scope in {'docs', 'all'}:
        for path in required:
            require(path)
        sources = [ROOT / p for p in ['README.md', 'START_HERE.md', 'AGENTS.md']]
        sources += sorted((ROOT / 'docs').rglob('*.md'))
        reachable = {ROOT / 'docs/INDEX.md'}
        edges = {}
        for source in sources:
            if not source.is_file():
                continue
            body = prose(source.read_text(encoding='utf-8'))
            edges[source.resolve()] = set()
            if re.search(r'\[[^\]]+\]\[[^\]]*\]', body):
                fail(source.relative_to(ROOT), '참조형 링크는 지원하지 않습니다. 인라인 링크로 바꾸거나 수동 확인 결과를 기록해 주세요.')
            for raw in re.findall(r'!?\[[^\]]*\]\(([^\n]+?)\)', body):
                target = raw.strip()
                if target.startswith('<') and target.endswith('>'):
                    target = target[1:-1]
                if urlsplit(target).scheme:
                    continue
                target_path, _, fragment = target.partition('#')
                resolved = (source.parent / unquote(target_path)).resolve() if target_path else source.resolve()
                if not resolved.is_relative_to(ROOT.resolve()):
                    fail(source.relative_to(ROOT), f'압축 파일 밖의 링크: {raw}')
                elif not resolved.exists():
                    fail(source.relative_to(ROOT), f'끊어진 링크: {raw}')
                else:
                    edges[source.resolve()].add(resolved)
                    if fragment and resolved.suffix == '.md' and unquote(fragment) not in anchors(resolved.read_text(encoding='utf-8')):
                        fail(source.relative_to(ROOT), f'없는 제목 링크: {raw}')
        reachable = {p.resolve() for p in reachable}
        pending = list(reachable)
        while pending:
            for target in edges.get(pending.pop(), set()):
                if target not in reachable:
                    reachable.add(target)
                    pending.append(target)
        for path in required:
            if path.startswith('docs/') and path.endswith('.md') and (ROOT / path).resolve() not in reachable:
                fail('docs/INDEX.md', f'색인에서 찾을 수 없는 문서: {path}')
    if scope in {'harness', 'all'}:
        roster_path = 'docs/operations/harness/team-spec.md'
        if require(roster_path):
            rows = []
            for line in (ROOT / roster_path).read_text(encoding='utf-8').splitlines():
                cells = [v.strip() for v in line.strip().strip('|').split('|')]
                if line.startswith('|') and len(cells) == 3 and re.fullmatch(ID_PATTERN, cells[0]) and cells[0] != 'role-id':
                    rows.append(cells)
            role_ids = [row[0] for row in rows]
            if not rows or len(role_ids) != len(set(role_ids)):
                fail(roster_path, '활성 역할이 없거나 role-id가 중복됩니다.')
            assigned = {r for row in rows for r in re.findall(r'\b(?:product|gameplay|ui|content|platform|data|qa)\b', row[1])}
            if assigned != RESPONSIBILITIES:
                fail(roster_path, f'담당 책임 누락: {sorted(RESPONSIBILITIES - assigned)}')
            skill_ids = {row[2] for row in rows}
            actual = {p.parent.name for p in (ROOT / '.agents/skills').glob('*/SKILL.md')}
            if skill_ids != actual:
                fail(roster_path, f'팀 명세와 스킬 폴더 불일치: {sorted(skill_ids ^ actual)}')
            for skill_id in sorted(skill_ids):
                if not re.fullmatch(ID_PATTERN, skill_id):
                    fail(roster_path, f'잘못된 스킬 ID: {skill_id}')
                    continue
                path = f'.agents/skills/{skill_id}/SKILL.md'
                if not require(path):
                    continue
                text = (ROOT / path).read_text(encoding='utf-8')
                front = re.match(r'^---\nname: ([^\n]+)\ndescription: ([^\n]+)\n---\n', text)
                if not front or front.group(1) != skill_id or not front.group(2).strip():
                    fail(path, 'YAML name·description 또는 폴더 이름을 확인해 주세요.')
                elif front.group(2).startswith('"'):
                    try:
                        description = json.loads(front.group(2))
                        if not isinstance(description, str) or not description.strip():
                            raise ValueError('빈 설명')
                    except ValueError:
                        fail(path, 'description의 따옴표와 문자열 형식을 확인해 주세요.')
                elif re.search(r':\s|\s#|[\[\]{}]', front.group(2)):
                    fail(path, 'description은 단순 문자열 또는 JSON 방식의 큰따옴표 문자열로 작성해 주세요.')
                for heading in ['사용 시점', '필수 입력', '작업 흐름', '산출물과 검증']:
                    section = re.search(r'^## '+heading+r'\n(.+?)(?=^## |\Z)', text, re.M | re.S)
                    if not section or not section.group(1).strip():
                        fail(path, f'필수 내용 누락: {heading}')
    if scope == 'all':
        for path in TOOLS:
            require(path)
        try:
            data = json.loads((ROOT / 'project-input.json').read_text(encoding='utf-8'))
            if state['status'] == 'configured' and data != state.get('applied_input'):
                fail('project-input.json', '설정 후 입력이 바뀌었습니다. 기존 결정을 보존하며 관련 문서를 수동으로 갱신해 주세요.')
            if state['status'] == 'configured':
                for key in ['game_name', 'project_id', 'core_play', 'first_goal']:
                    if not isinstance(data.get(key), str) or not data[key].strip():
                        fail('project-input.json', f'필수 입력 누락: {key}')
                if data.get('confirmed') is not True or data.get('project_id') != state.get('project_id') or data.get('game_name') != state.get('game_name'):
                    fail('bootstrap-state.json', '확인된 입력과 설정의 이름·ID가 일치해야 합니다.')
        except (OSError, ValueError):
            fail('project-input.json', '유효한 JSON 입력 양식이 필요합니다.')
        for p in ROOT.rglob('*'):
            rel = p.relative_to(ROOT)
            if not p.is_file() or p.suffix not in {'.md', '.json', '.sh'} or '.git' in rel.parts or str(rel) == GUIDE:
                continue
            text = p.read_text(encoding='utf-8')
            bad = [name for name in FORBIDDEN if name in text]
            if state['status'] == 'configured' and 'starter-game' in text:
                bad.append('임시 프로젝트 ID')
            if re.search(r'\{\{[A-Z_]+\}\}', text):
                bad.append('미치환 표시')
            if bad:
                fail(rel, f'다른 프로젝트 식별자 또는 치환 누락: {bad}')
        operating = ROOT / 'docs/operations/harness/operating-index.md'
        if operating.is_file():
            body = operating.read_text(encoding='utf-8')
            for path in TOOLS[2:]:
                if './'+path not in body:
                    fail(operating.relative_to(ROOT), f'검사 명령 누락: ./{path}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        print(f'bootstrap-{scope}: FAIL ({len(errors)})', file=sys.stderr)
        return 1
    print(f'bootstrap-{scope}: PASS')
    if state['status'] != 'configured':
        print('준비된 기본 뼈대입니다. 새 게임 설정 완료는 --require-configured로 별도 확인하세요.')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['docs', 'harness', 'all'], default='all')
    parser.add_argument('--require-configured', action='store_true')
    args = parser.parse_args()
    sys.exit(run(args.scope, args.require_configured))
