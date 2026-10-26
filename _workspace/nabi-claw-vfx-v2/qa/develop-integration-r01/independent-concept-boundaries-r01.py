"""Read-only adversarial checks of current/static scope and installation audit."""
from pathlib import Path
import ast
import contextlib
import copy
import io
import json
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
import install_personality_concepts as subject

OUT = Path(__file__).with_suffix('.json')
rows = []
original_read, original_sha = subject.read, subject.sha
manifest_path = ROOT / 'assets/character/manifest.json'
appearance_path = ROOT / 'docs/contracts/character-appearance-v01.json'
manifest = original_read(manifest_path)
before = original_read(ROOT / subject.TOPIC / '07_before_install/manifest.json')
receipt = original_read(ROOT / subject.TOPIC / 'installation.json')
expected = subject.expected_entries()

def run_case(name, callback, reject=False):
    detail = ''
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            callback()
    except AssertionError as exc:
        passed = reject
        detail = str(exc)
    else:
        passed = not reject
    rows.append({'case': name, 'expected': 'reject' if reject else 'accept', 'pass': passed, 'detail': detail})

def altered_manifest(value, strict=False):
    def read(path):
        return copy.deepcopy(value) if path == manifest_path else original_read(path)
    with patch.object(subject, 'read', side_effect=read):
        subject.check(preserve_install_snapshot=strict)

run_case('current checkout with later registered motions', subject.check)
for description, mutate in [
    ('canonical removed', lambda a: a.remove(next(e for e in a if e['type'] == 'concept'))),
    ('canonical reference changed', lambda a: next(e for e in a if e['type'] == 'concept').update(consumer_path='changed.md')),
    ('unknown canonical added', lambda a: a.append({'asset_id': 'unknown-concept', 'type': 'concept'})),
    ('duplicate canonical ID', lambda a: a.append(copy.deepcopy(next(e for e in a if e['type'] == 'concept')))),
    ('one approved variant missing', lambda a: a.remove(next(e for e in a if e['type'] == 'concept-variant'))),
    ('unknown variant added', lambda a: a.append({'asset_id': 'unknown-variant', 'type': 'concept-variant'})),
]:
    changed = copy.deepcopy(manifest)
    mutate(changed['assets'])
    run_case(description, lambda value=changed: altered_manifest(value), reject=True)

changed = copy.deepcopy(manifest)
next(e for e in changed['assets'] if e['type'] == 'animation-runtime')['sha256'] = '0' * 64
run_case('motion data belongs to separate motion validation', lambda: altered_manifest(changed))

def changed_appearance():
    def read(path):
        value = original_read(path)
        if path == appearance_path:
            value['characters'] = []
        return value
    with patch.object(subject, 'read', side_effect=read):
        subject.check()
run_case('appearance characters still protected', changed_appearance, reject=True)

# Restore historical manifest and original digest observations in memory only.
# This makes the audit reach every preserved-file branch despite later game work.
historical = copy.deepcopy(manifest)
historical['assets'] = before['assets'] + expected
def historical_audit(changed_path=None):
    def read(path):
        return copy.deepcopy(historical) if path == manifest_path else original_read(path)
    def sha(path):
        relative = str(path.relative_to(ROOT))
        if relative == changed_path:
            return '0' * 64
        return receipt['preserved_files'].get(relative, original_sha(path))
    with patch.object(subject, 'read', side_effect=read), patch.object(subject, 'sha', side_effect=sha):
        subject.check(preserve_install_snapshot=True)
run_case('installation audit positive baseline', historical_audit)
for folder in ('assets', 'scripts', 'scenes', 'forest_arena'):
    target = next(p for p in receipt['preserved_files'] if p.startswith(folder + '/') and '/concept/' not in p)
    run_case('installation audit rejects changed ' + folder, lambda p=target: historical_audit(p), reject=True)

changed = copy.deepcopy(historical)
next(e for e in changed['assets'] if e['type'] != 'concept-variant')['verified_on'] = 'altered'
run_case('installation audit retains exact old entry comparison', lambda: altered_manifest(changed, strict=True), reject=True)

tree = ast.parse((ROOT / 'tools/forest_arena/install_personality_concepts.py').read_text())
install = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'install')
strict_call = any(isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'check' and any(k.arg == 'preserve_install_snapshot' and isinstance(k.value, ast.Constant) and k.value.value is True for k in node.keywords) for node in ast.walk(install))
rows.append({'case': 'install explicitly calls strict preservation mode', 'expected': 'strict call', 'pass': strict_call, 'detail': 'AST read-only inspection'})
OUT.write_text(json.dumps({'status': 'pass' if all(r['pass'] for r in rows) else 'fix', 'checks': len(rows), 'rows': rows, 'scope': 'in-memory mutations only; no install, PNG or product write'}, ensure_ascii=False, indent=2) + '\n')
print('INDEPENDENT_CONCEPT_BOUNDARIES:', 'PASS' if all(r['pass'] for r in rows) else 'FAIL', f'({len(rows)} checks)')
sys.exit(0 if all(r['pass'] for r in rows) else 1)
