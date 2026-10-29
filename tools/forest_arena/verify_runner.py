#!/usr/bin/env python3
"""변경 파일에 맞는 검사를 선택하고 실행별 로그를 남긴다."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'tools/forest_arena/verification.json'
DIAGNOSTIC = re.compile(r'SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|: FAIL(?:\s|$)')
EXIT_LEAK = re.compile(r'^ERROR: \d+ resources still in use at exit.*$', re.M)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def changed_files(root=ROOT, base='origin/develop'):
    ancestor = git(root, 'merge-base', base, 'HEAD').decode().strip()
    names = git(root, 'diff', '--name-only', '-z', '--no-renames', ancestor, 'HEAD', '--')
    names += git(root, 'diff', '--cached', '--name-only', '-z', '--no-renames', 'HEAD', '--')
    names += git(root, 'diff', '--name-only', '-z', '--no-renames', '--')
    names += git(root, 'ls-files', '--others', '--exclude-standard', '-z')
    return sorted({os.fsdecode(p) for p in names.split(b'\0') if p})


def workspace_dependencies():
    result = {'_workspace/character-personality-concepts/': {'characters'},
              '_workspace/premium-menu-features-v01/state-runtime-coverage.json': {'menu', 'ui'},
              '_workspace/motion-naturalness-v1/02_expectations.md': {'characters'}}
    def visit(value, suite):
        if isinstance(value, dict):
            for item in value.values(): visit(item, suite)
        elif isinstance(value, list):
            for item in value: visit(item, suite)
        elif isinstance(value, str) and value.removeprefix('res://').startswith('_workspace/'):
            parts=value.removeprefix('res://').split('/')
            if len(parts)>2: result.setdefault('/'.join(parts[:2])+'/',set()).add(suite)
    for path,suite in [('assets/character/manifest.json','characters'),('assets/branding/myo-ryung-v02/manifest.json','branding')]:
        file=ROOT/path
        if file.is_file():visit(json.loads(file.read_text()),suite)
    return result

WORKSPACE_INPUTS = workspace_dependencies()


def suites_for(path):
    """좁은 규칙만 명시하고 알 수 없는 실행 코드/설정은 전체 검사한다."""
    if path.startswith(('build/', 'artifacts/')):
        return set()
    if path.startswith('_workspace/'):
        for prefix, selected in WORKSPACE_INPUTS.items():
            if (path == prefix or path.startswith(prefix)) and (not path.endswith(('.md', '.log')) or path == prefix):
                return selected
        # Task evidence is not shipped. Executable review tools still need validation.
        return {'full'} if Path(path).suffix in {'.py', '.gd', '.sh', '.mjs', '.cjs'} else set()
    if path in {'AGENTS.md', '.codex/config.toml.example'} or path.startswith('.agents/'):
        return {'harness', 'tooling'}
    if path in {'README.md', 'docs/INDEX.md', 'docs/GLOSSARY.md'} or (path.startswith('docs/') and path.endswith('.md')):
        return {'docs'}
    if path.startswith('assets/branding/'):
        return {'branding'}
    if path in {'project.godot', 'export_presets.cfg', '.gitignore', 'scripts/verify.sh'}:
        return {'full'}
    if path.startswith('docs/contracts/') or path.startswith('docs/ui/'):
        return {'characters', 'combat', 'ui', 'storage', 'network', 'resources'}
    if path.startswith(('forest_arena/data/', 'forest_arena/scripts/')):
        return {'resources', 'ui', 'characters', 'combat', 'smoke'}
    if path.startswith(('forest_arena/assets/audio/', 'assets/audio/')) or path in {'scripts/audio_director.gd', 'scripts/combat_audio.gd', 'scripts/audio_settings_store.gd'}:
        return {'audio', 'smoke'}
    if path in {'tools/forest_arena/combat_reference.py', 'tools/forest_arena/test_combat_reference.py'}:
        return {'characters', 'tooling'}
    if path.startswith(('assets/character/', 'tools/forest_arena/motion_', 'tools/forest_arena/review_motion', 'tools/forest_arena/register_motion')) or 'motion' in path and path.startswith('tools/forest_arena/'):
        return {'characters', 'combat', 'ui', 'smoke'}
    if path.startswith(('assets/combat/', 'assets/loadouts/', 'scripts/data/')):
        return {'combat', 'characters', 'storage', 'smoke'}
    if path.startswith(('forest_arena/assets/', 'assets/ui/')):
        return {'resources', 'ui', 'smoke'}
    if path.startswith(('server/', 'database/', 'scripts/network/')) or path in {'scripts/verify-online-server.sh', 'scripts/verify-lan-runtime.sh', 'scripts/verify-android-qa-lan.sh'}:
        return {'network', 'storage', 'smoke'}
    if path in {'scripts/combat_camera.gd', 'scripts/offscreen_opponent_indicator.gd', 'scripts/battle_minimap.gd'}:
        return {'presentation', 'battle-ui', 'smoke'}
    if path in {'scripts/local_fighter_presentation.gd'}:
        return {'presentation', 'characters', 'combat', 'resources', 'smoke'}
    if path in {'scripts/local_ai_command_source.gd'}:
        return {'ai', 'combat', 'smoke'}
    if path.startswith(('scripts/touch_', 'scripts/ui/touch_')):
        return {'touch', 'app', 'resources', 'smoke'}
    if path.startswith('scripts/') and Path(path).name in {
        'fighter_controller.gd', 'match_controller.gd', 'hit_resolver.gd', 'combat_math.gd', 'combo_controller.gd',
        'command_resolver.gd', 'pushbox_resolver.gd', 'combat_intent.gd', 'combat_camera.gd', 'local_ai_command_source.gd',
        'local_fighter_presentation.gd', 'stage_controller.gd', 'fighter_stub.gd', 'hit_context.gd', 'hit_result.gd',
        'local_match_config.gd', 'local_match_participant.gd', 'offscreen_opponent_indicator.gd',
    }:
        return {'combat', 'characters', 'presentation', 'battle-ui', 'ai', 'app', 'smoke'}
    if path.startswith('scripts/') and ('store' in path or 'service_client' in path):
        return {'storage', 'ui', 'network', 'resources', 'smoke'}
    if path.startswith(('scenes/', 'scripts/ui/')) or path.startswith('scripts/') and any(s in path for s in ['local_ai_app', 'startup', 'touch_', 'menu_', 'local_play_catalog']):
        return {'ui', 'combat', 'storage', 'resources', 'smoke'}
    if path.startswith(('tools/forest_arena/android_', 'tools/forest_arena/prepare_android', 'scripts/verify-android', 'scripts/export-')):
        return {'android', 'smoke'}
    if path in {'tools/forest_arena/verify_runner.py', 'tools/forest_arena/verification.json', 'tools/forest_arena/workflow.py', 'tools/forest_arena/test_verify_runner.py', 'tools/forest_arena/test_workflow.py', 'tools/forest_arena/verify_branding.py', 'tools/forest_arena/test_branding.py', 'tools/forest_arena/inspect_packaged_boot.gd'}:
        return {'tooling', 'branding', 'harness'}
    if path.endswith('.uid'):
        return suites_for(path[:-4])
    return {'full'}


def select_checks(paths, checks, requested=()):
    suites = set(requested)
    reasons = {}
    exact = {}
    for check in checks:
        for argument in check['command']:
            exact.setdefault(argument.removeprefix('res://').removeprefix('./'), set()).update(check['suites'])
    for path in paths:
        selected = exact.get(path, suites_for(path))
        reasons[path] = sorted(selected)
        suites.update(selected)
    full = 'full' in suites
    selected = [c for c in checks if full or suites.intersection(c['suites'])]
    return selected, reasons


def diagnostics(output):
    # Godot emits this existing shutdown leak diagnostic even for successful tests.
    # Preserve it in logs/results; never suppress script, parse or other engine errors.
    warnings = EXIT_LEAK.findall(output)
    cleaned = EXIT_LEAK.sub('', output)
    return bool(DIAGNOSTIC.search(cleaned)), warnings


def execute(checks, root=ROOT):
    from workflow import operation_lock, run_process
    run_id = time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]
    output = root / 'build/verification' / run_id
    records = []
    started = time.monotonic()
    with operation_lock(root):
        output.mkdir(parents=True)
        env = os.environ.copy()
        env['FOREST_ARENA_VERIFY_OUTPUT'] = str(output)
        needs_import = any(c.get('godot') for c in checks)
        commands = ([{'id': 'godot-import', 'command': ['godot', '--headless', '--path', '.', '--editor', '--quit'], 'timeout': 180}] if needs_import else []) + checks
        source_commit = git(root, 'rev-parse', 'HEAD').decode().strip()
        report = {'status': 'running', 'source_commit': source_commit, 'elapsed_seconds': 0,
                  'total_checks': len(commands), 'completed_checks': 0, 'checks': records}
        (output/'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
        for index, check in enumerate(commands, 1):
            log = output / (check['id'] + '.log')
            print(f'[{index}/{len(commands)}] {check["id"]}', flush=True)
            step = time.monotonic()
            try:
                with log.open('w') as stream:
                    result = run_process(check['command'], cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=check.get('timeout', 600))
                code = result.returncode
            except (OSError, subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                with log.open('a') as stream: stream.write('\n' + str(error) + '\n')
                code = 130 if isinstance(error, KeyboardInterrupt) else 124
            contents = log.read_text(errors='replace')
            bad, warnings = diagnostics(contents)
            status = 'interrupted' if code == 130 else 'pass' if code == 0 and not bad else 'fail'
            records.append({'id': check['id'], 'command': check['command'], 'status': status, 'exit_code': code, 'elapsed_seconds': round(time.monotonic()-step, 3), 'log_bytes': log.stat().st_size, 'shutdown_diagnostics': warnings})
            report = {'status': status if status != 'pass' or index == len(commands) else 'running', 'source_commit': source_commit, 'elapsed_seconds': round(time.monotonic()-started, 3), 'total_checks': len(commands), 'completed_checks': len(records), 'checks': records}
            (output/'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
            if status != 'pass':
                print(contents[-4000:])
                print(f'FAIL: {check["id"]}; 전체 로그: {log}', file=sys.stderr)
                return 1
            if check['id'] == 'godot-import': env['FOREST_ARENA_GODOT_IMPORTED'] = '1'
    print(f'PASS: {len(checks)}개 검사, {time.monotonic()-started:.1f}초; 결과: {output}/result.json')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--full', action='store_true')
    group.add_argument('--changed', action='store_true')
    group.add_argument('--suite', action='append', choices=json.loads(MANIFEST.read_text())['suites'])
    parser.add_argument('--base', default='origin/develop')
    parser.add_argument('--list', action='store_true', help='선택 이유와 명령만 출력; 실행하지 않음')
    args = parser.parse_args()
    checks = json.loads(MANIFEST.read_text())['checks']
    paths = []
    if args.full or args.suite:
        selected, reasons = select_checks([], checks, ['full'] if args.full else args.suite)
    else:
        try: paths = changed_files(base=args.base)
        except subprocess.CalledProcessError as error:
            print(f'변경 기준을 확인할 수 없습니다 ({args.base}); --base 또는 --full을 사용하세요.', file=sys.stderr)
            return 2
        selected, reasons = select_checks(paths, checks)
    print(f'변경 파일 {len(paths)}개; 선택 검사 {len(selected)}개', flush=True)
    if args.list:
        print(json.dumps({'reasons': reasons, 'checks': selected}, ensure_ascii=False, indent=2))
        return 0
    if not selected:
        print('실행할 검사가 없습니다. 전체 검사는 --full로 실행합니다.')
        return 0
    try: return execute(selected)
    except (RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 75

if __name__ == '__main__':
    raise SystemExit(main())
